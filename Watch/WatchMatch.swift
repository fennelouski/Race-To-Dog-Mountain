import Foundation

struct WatchMatch: Codable, Sendable {
    static let saveKey = "watchMatch.v1"
    private static let skillKey = "watchSkill.v1"
    let id: UUID
    let difficulty: ComputerDifficulty
    let computers: [Bool]
    let adjustment: Int
    private(set) var game: MountainGame
    private(set) var replay: MountainReplay?
    private(set) var computerStarted = false
    private(set) var recorded = false

    private struct Skill: Codable {
        let difficulty: ComputerDifficulty
        let adjustment: Int
        let match: UUID
    }

    init(size: Int, difficulty: ComputerDifficulty, computers: [Bool], defaults: UserDefaults = .standard) {
        id = UUID()
        self.difficulty = difficulty
        self.computers = computers.count == 2 ? computers : [false, true]
        let skill = defaults.data(forKey: Self.skillKey).flatMap { try? JSONDecoder().decode(Skill.self, from: $0) }
        adjustment = skill?.difficulty == difficulty ? min(2, max(-2, skill!.adjustment)) : 0
        game = MountainGame(size: size, firstPlayer: MountainGame.startingPlayer(computers: self.computers))
    }

    var waitingForStart: Bool { game.moves == 0 && computers[game.turn] && !computerStarted }
    func canComputerMove(active: Bool, paused: Bool) -> Bool {
        active && !paused && !waitingForStart && !game.isOver && computers[game.turn]
    }
    mutating func startComputer() { computerStarted = true }

    @discardableResult mutating func play(_ tile: Int, computer: Bool = false, defaults: UserDefaults = .standard) -> Bool {
        guard computers[game.turn] == computer, !waitingForStart, game.canPlay(tile) else { return false }
        if computer { replay = MountainReplay(before: game, tileID: tile, difficulty: difficulty) }
        game.play(tile)
        if game.isOver && !recorded {
            recorded = true
            if computers.filter({ $0 }).count == 1 && game.scores[0] != game.scores[1] {
                let previous = defaults.data(forKey: Self.skillKey).flatMap { try? JSONDecoder().decode(Skill.self, from: $0) }
                if previous?.match != id {
                    let winner = game.scores[0] > game.scores[1] ? 0 : 1
                    let skill = Skill(difficulty: difficulty, adjustment: ComputerDifficulty.adjusted(adjustment, humanWon: !computers[winner]), match: id)
                    if let data = try? JSONEncoder().encode(skill) { defaults.set(data, forKey: Self.skillKey) }
                }
            }
        }
        save(defaults: defaults)
        return true
    }
    func save(defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: Self.saveKey) }
    }
    static func restore(defaults: UserDefaults = .standard) -> WatchMatch? {
        guard let data = defaults.data(forKey: saveKey), data.count < 262_144,
              let match = try? JSONDecoder().decode(Self.self, from: data),
              match.computers.count == 2, (-2...2).contains(match.adjustment), valid(match.game),
              match.game.turn == (MountainGame.startingPlayer(computers: match.computers) + match.game.moves) % 2 else { return nil }
        if let replay = match.replay {
            guard valid(replay.before), replay.before.canPlay(replay.tileID), replay.before.size == match.game.size,
                  match.computers[replay.before.turn], replay.difficulty == match.difficulty,
                  replay.before.moves < match.game.moves else { return nil }
        }
        return match
    }
    private static func valid(_ game: MountainGame) -> Bool {
        guard (4...14).contains(game.size) else { return false }
        let count = game.size * game.size, total = count * (count + 1) / 2
        guard game.tiles.count == count, game.scores.count == 2, (0...1).contains(game.turn),
              (0..<game.size).contains(game.row), (0..<game.size).contains(game.column),
              game.scores.allSatisfy({ (0...total).contains($0) }),
              game.tiles.enumerated().allSatisfy({ $0.offset == $0.element.id && (0...count).contains($0.element.value) }) else { return false }
        let remaining = game.tiles.filter { $0.value > 0 }.map(\.value)
        return Set(remaining).count == remaining.count && game.moves == count - remaining.count
            && remaining.reduce(0, +) + game.scores.reduce(0, +) == total
    }
}
