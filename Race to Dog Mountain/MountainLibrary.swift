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
        var next = games
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
