import Foundation
import Observation

@MainActor @Observable final class MountainLibrary {
    private(set) var games: [SavedMountainGame]
    var error: String?
    private let defaults: UserDefaults
    private static let key = "mountainGames.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key) {
            if data.count <= 4_194_304, let saved = try? JSONDecoder().decode([SavedMountainGame].self, from: data),
               saved.allSatisfy(\.isValid), Set(saved.map(\.id)).count == saved.count {
                games = saved
            } else {
                games = []; error = "Saved games couldn't be read. The original data has been kept."
            }
        } else { games = [] }
    }
    func save(_ game: SavedMountainGame) {
        guard game.isValid else { error = "This game couldn't be saved."; return }
        // Merge the freshest persisted library so a retired scene cannot erase a newer game.
        var next = games
        if let data = defaults.data(forKey: Self.key), data.count <= 4_194_304,
           let latest = try? JSONDecoder().decode([SavedMountainGame].self, from: data),
           latest.allSatisfy(\.isValid), Set(latest.map(\.id)).count == latest.count { next = latest }
        if let current = next.first(where: { $0.id == game.id }), current.game.moves > game.game.moves { games = next; return }
        if let index = next.firstIndex(where: { $0.id == game.id }) { next[index] = game }
        else { next.append(game) }
        do {
            let data = try JSONEncoder().encode(next)
            guard data.count <= 4_194_304 else { error = "The saved games library is full. This game could not be saved."; return }
            // Keep unreadable old data available rather than overwriting the only copy.
            if games.isEmpty, error != nil, let old = defaults.data(forKey: Self.key) {
                defaults.set(old, forKey: Self.key + ".recovery")
            }
            defaults.set(data, forKey: Self.key)
            games = next; error = nil
        } catch { self.error = "The game couldn't be saved. Try again before closing it." }
    }
    var active: [SavedMountainGame] { games.filter { !$0.game.isOver }.sorted { $0.updatedAt > $1.updatedAt } }
    var finished: [SavedMountainGame] { games.filter { $0.game.isOver }.sorted { $0.updatedAt > $1.updatedAt } }
}

@MainActor @Observable final class MountainLearningStore {
    static let shared = MountainLearningStore()
    private struct Profile: Codable {
        var generation = UUID()
        var learning = MountainLearning()
        var completed: [UUID] = []
        var isValid: Bool { learning.isValid && completed.count <= 256 && Set(completed).count == completed.count }
    }
    private var revision = 0
    private let defaults: UserDefaults
    private static let storageKey = "mountainLearning.v1"
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    private func decode(_ data: Data) -> [String: Profile]? {
        guard data.count <= 4_194_304,
              let decoded = try? JSONDecoder().decode([String: Profile].self, from: data),
              decoded.count <= 256, decoded.values.allSatisfy(\.isValid) else { return nil }
        return decoded
    }
    private func load() -> [String: Profile] {
        defaults.data(forKey: Self.storageKey).flatMap(decode) ?? [:]
    }
    static func key(name: String, size: Int, seat: Int) -> String {
        // Match the app's named local players; keep row/column roles and board sizes separate.
        "\(name.utf8.count):\(name)|\(size)|\(seat)"
    }
    func learning(for key: String) -> MountainLearning {
        _ = revision
        return load()[key]?.learning ?? MountainLearning()
    }
    func begin(key: String) -> MountainLearningContext {
        var profiles = load()
        if profiles[key] == nil {
            // Keep local storage bounded without erasing an existing player's progress.
            if profiles.count < 256 { profiles[key] = Profile(); persist(profiles) }
        }
        return MountainLearningContext(key: key, generation: profiles[key]?.generation ?? UUID())
    }
    @discardableResult func record(_ outcome: MountainLearning.Outcome, gameID: UUID, context: MountainLearningContext) -> Bool {
        // Each main-actor mutation reads the latest data, including another window's result or reset.
        var profiles = load()
        guard var profile = profiles[context.key], profile.generation == context.generation,
              !profile.completed.contains(gameID) else { return false }
        profile.learning.record(outcome)
        profile.completed.append(gameID); profile.completed = Array(profile.completed.suffix(256))
        profiles[context.key] = profile; persist(profiles); return true
    }
    func reset(key: String) {
        var profiles = load()
        guard profiles[key] != nil || profiles.count < 256 else { return }
        // Rotate the generation: finishing a game started before Reset cannot restore old learning.
        profiles[key] = Profile(); persist(profiles)
    }
    private func persist(_ profiles: [String: Profile]) {
        guard let data = try? JSONEncoder().encode(profiles), data.count <= 4_194_304 else { return }
        if let old = defaults.data(forKey: Self.storageKey), decode(old) == nil {
            defaults.set(old, forKey: Self.storageKey + ".recovery")
        }
        defaults.set(data, forKey: Self.storageKey)
        revision += 1
    }
}

/// Read-only snapshots cross the display boundary; the primary view alone owns game mutation and AI.
@MainActor @Observable final class MountainDisplayHub {
    static let shared = MountainDisplayHub()
    private(set) var snapshot: MountainDisplaySnapshot?
    private(set) var connections: Set<String> = []
    private(set) var activeOwner: UUID?
    func claim(owner: UUID) {
        if activeOwner != owner { snapshot = nil }
        activeOwner = owner
    }
    func publish(_ next: MountainDisplaySnapshot) {
        guard activeOwner == next.owner else { return }
        if let current = snapshot, current.owner == next.owner, current.game.moves > next.game.moves { return }
        snapshot = next
    }
    func clear(owner: UUID) { if activeOwner == owner { snapshot = nil; activeOwner = nil } }
    func connected(_ scene: String) { connections.insert(scene) }
    func disconnected(_ scene: String) { connections.remove(scene) }
}
