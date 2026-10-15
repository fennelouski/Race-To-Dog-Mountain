import Foundation

enum ComputerDifficulty: Int, CaseIterable, Identifiable, Sendable, Codable {
    case level1, level2, level3, level4, level5, level6, level7, level8
    case level9, level10, level11, level12, level13, level14, level15, level16
    var id: Int { rawValue }
    var name: String { ["Quinn", "Milo", "June", "Theo", "Amara", "Finn", "Leila", "Oscar", "Nia", "Hugo", "Sana", "Ezra", "Inez", "Kai", "Zuri", "Avery"][rawValue] }
    var title: String { "Level \(rawValue + 1)" }
    var displayName: String { "\(name) (\(rawValue + 1))" }
    var portrait: String { "Opponent\(rawValue + 1)" }
    var detail: String {
        ["Curious beginner", "Easygoing explorer", "Enthusiastic newcomer", "Patient trail walker", "Careful route finder", "Adventurous thinker", "Observant challenger", "Steady tactician", "Playful strategist", "Quiet problem solver", "Focused planner", "Analytical navigator", "Confident climber", "Precise pathfinder", "Inventive expert", "Summit strategist"][rawValue]
    }
    var depth: Int { rawValue / 4 + 1 }
    var branches: Int { rawValue % 4 + 3 }
    var accuracy: Double { 0.10 + Double(rawValue) * (0.88 / 15) }
    var greeting: String {
        ["Let's learn the trail together.", "No rush. Let's enjoy the climb.", "Ready to try a new route?", "One thoughtful step at a time.", "Let's see where the numbers take us.", "I have a good feeling about this climb.", "There's always another angle.", "Let's put our plans to the test.", "Care for a friendly challenge?", "I'll take a moment to think.", "Ready when you are.", "Every choice changes the possibilities.", "Let's find the cleanest route.", "The small details matter.", "Let's try something unexpected.", "A good climb starts with a good choice."][rawValue]
    }
    func phrase(move: Int) -> String {
        let phrases = [
            ["That looked promising!", "I'm still finding my feet.", "Your turn to explore."],
            ["Nice and steady.", "Let's see what happens next.", "Plenty of trail ahead."],
            ["Found a new path!", "Let's keep moving.", "I wonder what you'll choose."],
            ["A little patience goes a long way.", "One step, then the next.", "Take your time."],
            ["That opens a useful route.", "I've checked the next turn.", "What will you leave me?"],
            ["Let's follow this one.", "A bold step can pay off.", "Your adventure continues."],
            ["Did you notice that column?", "There's more than one way through.", "Look at the next row."],
            ["A steady route is still a route.", "Now we test the plan.", "Your next move matters."],
            ["A little twist in the trail.", "This is getting interesting.", "Surprise me."],
            ["I've thought through a few turns.", "No need to rush the choice.", "The next step is yours."],
            ["Keep an eye on what follows.", "This route has potential.", "Your move, your plan."],
            ["The possibilities just changed.", "I compared a few routes.", "Which reply do you prefer?"],
            ["A clean path through the numbers.", "I'll take the longer view.", "Think one turn beyond mine."],
            ["A small detail can decide the climb.", "I weighed the next few steps.", "Choose your reply carefully."],
            ["An unexpected route can be useful.", "Let's change the shape of the game.", "I have another idea."],
            ["Look beyond the next step.", "Every route has a tradeoff.", "The summit takes planning."]
        ]
        return phrases[rawValue][move % 3]
    }
    func resultPhrase(humanWon: Bool) -> String {
        humanWon ? ["You found the route!", "A lovely climb. Well played.", "That was a clever adventure!", "Your patience paid off.", "You spotted the better path.", "A bold finish. Nice work!", "You saw something I missed.", "Your plan held up. Well played.", "A delightful surprise!", "You gave me something to think about.", "A well-earned finish.", "Your choices made the difference.", "An excellent climb.", "You caught the decisive detail.", "A creative route to victory!", "A worthy ascent. You earned the summit."][rawValue]
            : ["Another try? We'll learn together.", "There's always another trail.", "Next adventure, new possibilities.", "Take another steady climb.", "Let's find a different route.", "The next climb could be yours.", "Try another angle next time.", "A new plan, a new game.", "Let's play another friendly round.", "A fresh board gives us both a fresh start.", "Another chance to test your plan.", "The next game has new possibilities.", "Let's explore another path.", "There's another route waiting.", "Try something unexpected next time.", "The mountain will be here for another climb."][rawValue]
    }
    static func adjusted(_ current: Int, humanWon: Bool) -> Int {
        min(2, max(-2, current + (humanWon ? 1 : -1)))
    }
}

struct MountainGame: Sendable, Codable {
    struct Tile: Identifiable, Sendable, Codable {
        let id: Int
        var value: Int
    }
    let size: Int
    private(set) var tiles: [Tile]
    private(set) var scores = [0, 0]
    private(set) var turn: Int
    private(set) var row: Int
    private(set) var column: Int
    private(set) var moves = 0

    init(size: Int, values: [Int]? = nil, firstPlayer: Int = 0, startingLine: Int? = nil) {
        self.size = min(max(size, 4), 14)
        let side = self.size
        let count = side * side
        let numbers = values?.count == count ? values! : Array(1...count).shuffled()
        tiles = numbers.enumerated().map { Tile(id: $0.offset, value: $0.element) }
        turn = min(max(firstPlayer, 0), 1)
        row = min(max(startingLine ?? Int.random(in: 0..<self.size), 0), self.size - 1)
        column = row
    }

    func canPlay(_ id: Int) -> Bool {
        guard tiles.indices.contains(id), tiles[id].value > 0 else { return false }
        return turn == 0 ? id / size == row : id % size == column
    }
    var legalMoves: [Int] { tiles.filter { canPlay($0.id) }.map(\.id) }
    var isOver: Bool { legalMoves.isEmpty }

    @discardableResult mutating func play(_ id: Int) -> Bool {
        guard canPlay(id) else { return false }
        scores[turn] += tiles[id].value
        if turn == 0 { column = id % size }
        else { row = id / size }
        tiles[id].value = 0
        turn = 1 - turn
        moves += 1
        return true
    }

    static func startingPlayer(computers: [Bool]) -> Int {
        computers.firstIndex(of: false) ?? 0
    }

    static func randomStartingPlayer(computers: [Bool], coin: Int? = nil) -> Int {
        guard computers.contains(true) else { return 0 }
        return coin.map { min(1, max(0, $0)) } ?? Int.random(in: 0...1)
    }

    func computerMove(difficulty: ComputerDifficulty = .level6, adjustment: Int = 0, roll: Double? = nil) -> Int? {
        var random = SystemRandomNumberGenerator()
        return computerMove(difficulty: difficulty, adjustment: adjustment, roll: roll, using: &random)
    }
    func computerMove<R: RandomNumberGenerator>(difficulty: ComputerDifficulty, adjustment: Int = 0, roll: Double? = nil, using random: inout R) -> Int? {
        let evaluatedMoves: [(id: Int, value: Int)] = legalMoves.map { id in
            (id: id, value: evaluated(id, depth: difficulty.depth, branches: difficulty.branches))
        }
        let ranked = evaluatedMoves.sorted { left, right in
            if left.value == right.value { return left.id < right.id }
            return left.value > right.value
        }.map(\.id)
        guard let best = ranked.first else { return nil }
        let accuracy = min(1, max(0, difficulty.accuracy + Double(min(2, max(-2, adjustment))) * 0.0125))
        if (roll ?? Double.random(in: 0..<1, using: &random)) < accuracy || ranked.count == 1 { return best }
        // A softer opponent sometimes picks another promising route, not an illegal move.
        let alternatives = Array(ranked.dropFirst().prefix(difficulty.rawValue < 4 ? ranked.count : 3))
        return alternatives.randomElement(using: &random) ?? best
    }
    private func evaluated(_ id: Int, depth: Int, branches: Int) -> Int {
        var next = self
        next.play(id)
        return tiles[id].value - next.bestValue(depth: depth - 1, branches: branches)
    }
    private func bestValue(depth: Int, branches: Int) -> Int {
        guard depth > 0 else { return 0 }
        // ponytail: at most six branches per deeper ply bounds large-board work; widen after profiling.
        return legalMoves.sorted { tiles[$0].value > tiles[$1].value }.prefix(branches)
            .map { evaluated($0, depth: depth, branches: branches) }.max() ?? 0
    }

}

extension MountainGame {
    var isValid: Bool {
        guard (4...14).contains(size) else { return false }
        let count = size * size, total = count * (count + 1) / 2
        guard tiles.count == count, scores.count == 2, (0...1).contains(turn),
              (0..<size).contains(row), (0..<size).contains(column), (0...count).contains(moves),
              scores.allSatisfy({ (0...total).contains($0) }),
              tiles.enumerated().allSatisfy({ $0.offset == $0.element.id && (0...count).contains($0.element.value) }) else { return false }
        let remaining = tiles.filter { $0.value > 0 }.map(\.value)
        return Set(remaining).count == remaining.count && count - remaining.count == moves &&
            scores.reduce(0, +) + remaining.reduce(0, +) == total
    }
}

struct MountainReplay: Sendable, Codable {
    let before: MountainGame
    let tileID: Int
    let difficulty: ComputerDifficulty
    var after: MountainGame {
        var result = before
        result.play(tileID)
        return result
    }
}


// Only a DEBUG launch with an explicit valid UUID may use the private QA store.
enum MountainExperience {
    static let qaSession: UUID? = {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-MountainUITests") else { return nil }
        guard let flag = args.firstIndex(of: "-MountainTestSession"),
              args.indices.contains(flag + 1), let id = UUID(uuidString: args[flag + 1]) else {
            fatalError("Private Mountain QA requires a valid session UUID")
        }
        return id
        #else
        return nil
        #endif
    }()
    static var isQAActive: Bool { qaSession != nil }
    static let defaults: UserDefaults = {
        guard let id = qaSession else { return .standard }
        return UserDefaults(suiteName: "com.codex.racedog.qa." + id.uuidString)!
    }()
    static var animationsEnabled: Bool { defaults.object(forKey: "animationsEnabled") as? Bool ?? true }
    static var hapticsEnabled: Bool { defaults.object(forKey: "hapticsEnabled") as? Bool ?? true }
    static var computerDuration: Double {
        let value = defaults.object(forKey: "computerMoveDuration") as? Double ?? 0.7
        return value.isFinite ? min(1.2, max(0.4, value)) : 0.7
    }
}

#if canImport(ObjectiveC)
@objc(MountainQARuntime) public final class MountainQARuntime: NSObject {
    @objc public static var isActive: Bool { MountainExperience.isQAActive }
}
#endif

/// The initial board and successful legal choices are enough to reproduce a game.
/// Optional on legacy saves: missing moves must never be invented.
struct MountainHistory: Codable, Sendable {
    let initial: MountainGame
    private(set) var choices: [Int] = []
    init(initial: MountainGame) { self.initial = initial }
    var states: [MountainGame]? {
        guard initial.isValid, initial.moves == 0, choices.count <= initial.size * initial.size else { return nil }
        var game = initial
        var result = [game]
        for tile in choices {
            guard game.play(tile) else { return nil }
            result.append(game)
        }
        return result
    }
    func matches(_ game: MountainGame) -> Bool {
        guard let last = states?.last else { return false }
        return last.size == game.size && last.turn == game.turn && last.moves == game.moves &&
            last.row == game.row && last.column == game.column && last.scores == game.scores &&
            last.tiles.map(\.value) == game.tiles.map(\.value)
    }
    @discardableResult mutating func record(_ tile: Int, before: MountainGame) -> Bool {
        guard matches(before), before.canPlay(tile), choices.count < initial.size * initial.size else { return false }
        choices.append(tile)
        return true
    }
}

#if DOGMOUNTAIN_CHECKS
@main enum MountainGameCheck {
    static func main() {
        var classic = MountainGame(size: 4, values: Array(1...16), firstPlayer: 0, startingLine: 0)
        assert(!classic.play(4))
        assert(classic.play(2) && classic.scores == [3, 0] && classic.turn == 1)
        assert(!classic.play(2) && !classic.play(5))
        assert(classic.play(14) && classic.scores == [3, 15] && classic.row == 3)
        assert(!classic.play(-1) && !classic.play(16))
        assert(MountainGame(size: 1).size == 4 && MountainGame(size: 99).size == 14)
        assert(MountainGame(size: 4).turn == 0)
        assert(MountainGame.startingPlayer(computers: [false, true]) == 0)
        assert(MountainGame.startingPlayer(computers: [true, false]) == 1)
        assert(MountainGame.startingPlayer(computers: [true, true]) == 0)
        assert(ComputerDifficulty.adjusted(0, humanWon: true) == 1)
        assert(ComputerDifficulty.adjusted(0, humanWon: false) == -1)
        assert(ComputerDifficulty.adjusted(2, humanWon: true) == 2)
        assert(ComputerDifficulty.adjusted(-2, humanWon: false) == -2)
        let before = classic
        let replay = MountainReplay(before: before, tileID: before.legalMoves[0], difficulty: .level6)
        assert(replay.after.moves == before.moves + 1 && classic.moves == before.moves)
        assert(replay.after.tiles[replay.tileID].value == 0)
        for difficulty in ComputerDifficulty.allCases {
            for side in [4, 6, 14] {
                var game = MountainGame(size: side)
                for roll in [0.0, 0.999] { assert(game.canPlay(game.computerMove(difficulty: difficulty, roll: roll)!)) }
                while let move = game.computerMove(difficulty: difficulty, roll: 0) {
                    assert(game.play(move)); assert(game.moves <= side * side)
                }
                assert(game.isOver && game.scores.reduce(0, +) + game.tiles.map(\.value).reduce(0, +) == (side * side) * (side * side + 1) / 2)
            }
        }
        print("Classic rules, human starts, replay isolation, bounded adaptation, sixteen AI levels and score conservation passed.")
    }
}
#endif

/// Local, between-game AIMD controller. Outcomes guide challenge; they never alter a board or score.
struct MountainLearning: Codable, Sendable {
    enum Outcome: String, Codable, Sendable { case win, loss, tie }
    private(set) var skill = 0.0
    private(set) var recent: [Outcome] = []
    private(set) var cooldown = 0
    var difficulty: ComputerDifficulty { ComputerDifficulty(rawValue: Int(skill.rounded(.down))) ?? .level1 }
    var winRate: Double? {
        let decisive = recent.filter { $0 != .tie }
        guard !decisive.isEmpty else { return nil }
        return Double(decisive.filter { $0 == .win }.count) / Double(decisive.count)
    }
    var isValid: Bool {
        skill.isFinite && (0...15).contains(skill) && recent.count <= 12 && (0...2).contains(cooldown)
    }
    mutating func record(_ outcome: Outcome) {
        // Ties do not count as wins or losses, and break a winning/losing streak.
        recent.append(outcome); recent = Array(recent.suffix(12))
        if cooldown > 0 { cooldown -= 1; return }
        let decisive = recent.filter { $0 != .tie }
        guard outcome != .tie, decisive.count >= 4 else { return }
        let wins = Double(decisive.filter { $0 == .win }.count)
        // Four prior observations centred on 65% damp short-session noise.
        let smoothed = (wins + 2.6) / (Double(decisive.count) + 4)
        let pair = Array(recent.suffix(2))
        if outcome == .loss && smoothed < 0.60 {
            skill = max(0, skill * 0.65)
            cooldown = 2
        } else if outcome == .win && pair == [.win, .win] && smoothed > 0.70 {
            skill = min(15, skill + 0.25)
            cooldown = 2
        }
    }
}

struct MountainLearningContext: Codable, Sendable {
    let key: String
    let generation: UUID
}

/// Pure geometry policy, shared by live, friend and replay boards.
struct MountainBoardLayout {
    let tile: Double
    let extent: Double
    let scrolls: Bool
    static let padding = 8.0
    static let gap = 4.0
    init(size: Int, availableWidth: Double, availableHeight: Double? = nil, compact: Bool, scrollThreshold: Int, minimumTile: Double) {
        let side = Double(min(14, max(4, size)))
        scrolls = compact && size > min(14, max(4, scrollThreshold))
        let available = max(64, availableWidth)
        let fittedExtent = min(available, availableHeight.map { max(64, $0) } ?? available)
        let fittedTile = max(1, (fittedExtent - Self.padding * 2 - Self.gap * (side - 1)) / side)
        tile = scrolls ? max(minimumTile, fittedTile) : fittedTile
        extent = tile * side + Self.gap * (side - 1) + Self.padding * 2
    }
}

/// Decorative solar timing only: local civil time plus a coarse seasonal latitude
/// estimate. It requests no location and makes no astronomical accuracy claim.
struct MountainSky {
    let daylight: Double
    let sunProgress: Double
    init(date: Date, timeZone: TimeZone = .current) {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.hour, .minute, .second], from: date)
        let hour = Double(parts.hour ?? 12) + Double(parts.minute ?? 0) / 60 + Double(parts.second ?? 0) / 3600
        let day = Double(calendar.ordinality(of: .day, in: .year, for: date) ?? 182)
        let zone = timeZone.identifier
        let latitudes: [String: Double] = ["Europe/Amsterdam": 52, "Europe/London": 51, "America/New_York": 41, "America/Los_Angeles": 34, "America/Chicago": 42, "America/Toronto": 44, "Asia/Tokyo": 36, "Asia/Singapore": 1, "Asia/Kolkata": 23, "Australia/Sydney": -34, "Pacific/Auckland": -37, "America/Sao_Paulo": -24]
        let latitude = latitudes[zone] ?? (zone.hasPrefix("Australia/") ? -30 : zone.hasPrefix("Africa/") ? 0 : 35)
        let season = sin((day - 80) / 365.25 * 2 * .pi)
        let length = min(17, max(7, 12 + 4 * season * latitude / 52))
        let sunrise = 12 - length / 2, sunset = 12 + length / 2
        daylight = min(1, max(0, min(hour - sunrise + 0.5, sunset - hour + 0.5)))
        sunProgress = min(1, max(0, (hour - sunrise) / length))
    }
}

/// An isolated, deterministic teaching board. Never enters saved games or learning.
struct MountainTutorial {
    static let lastStep = 4
    private(set) var step = 0
    private var states = [MountainGame(size: 4, values: [4, 11, 2, 8, 13, 6, 15, 1, 7, 16, 3, 10, 12, 5, 14, 9], firstPlayer: 0, startingLine: 1)]
    private var choices: [Int] = []
    var game: MountainGame { states[step] }
    var finished: Bool { step == Self.lastStep }
    var canGoForward: Bool { step + 1 < states.count }
    var lastMove: Int? { step > 0 ? choices[step - 1] : nil }
    var lastPoints: Int { lastMove.map { states[step - 1].tiles[$0].value } ?? 0 }
    @discardableResult mutating func choose(_ tile: Int) -> Bool {
        guard !finished, game.canPlay(tile) else { return false }
        var next = game
        guard next.play(tile) else { return false }
        states = Array(states.prefix(step + 1)) + [next]
        choices = Array(choices.prefix(step)) + [tile]
        step += 1
        return true
    }
    mutating func navigate(to page: Int) {
        guard (0..<states.count).contains(page) else { return }
        step = page
    }
}

struct MountainHumanProfile: Codable {
    var displayName: String
    var symbol: String
    var avatarStyle: String? = nil
    var photoID: String? = nil
    var resolvedStyle: String { avatarStyle ?? (symbol == "person.fill" ? "fonster" : "symbol") }
    static let symbols = ["person.fill", "pawprint.fill", "leaf.fill", "sun.max.fill", "mountain.2.fill", "sparkles"]
    static func read(identity: String, data: Data) -> Self {
        let profiles = (data.count < 262_144 ? try? JSONDecoder().decode([String: Self].self, from: data) : nil) ?? [:]
        guard let profile = profiles[identity], symbols.contains(profile.symbol) else { return Self(displayName: identity, symbol: "person.fill") }
        return Self(displayName: String(profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60)).isEmpty ? identity : String(profile.displayName.prefix(60)), symbol: profile.symbol, avatarStyle: ["fonster", "symbol", "photo"].contains(profile.resolvedStyle) ? profile.resolvedStyle : "fonster", photoID: profile.photoID.flatMap { UUID(uuidString: $0) == nil ? nil : $0 })
    }
    static func updating(identity: String, displayName: String, symbol: String, data: Data, avatarStyle: String? = nil, photoID: String? = nil) -> Data? {
        guard symbols.contains(symbol), avatarStyle == nil || ["fonster", "symbol", "photo"].contains(avatarStyle!), photoID == nil || UUID(uuidString: photoID!) != nil else { return nil }
        var profiles = (data.count < 262_144 ? try? JSONDecoder().decode([String: Self].self, from: data) : nil) ?? [:]
        let name = String(displayName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
        profiles[identity] = Self(displayName: name.isEmpty ? identity : name, symbol: symbol, avatarStyle: avatarStyle, photoID: photoID)
        guard profiles.count <= 256 else { return nil }
        return try? JSONEncoder().encode(profiles)
    }
}

struct MountainMoveFeedback: Identifiable, Sendable {
    let id: Int
    let token = UUID() // A late completion can never remove a later game’s move with the same number.
    let tile: Int
    let player: Int
    let points: Int
    let maximum: Int
    static let maximumActive = 4
    static let duration = 0.9
    var particleCount: Int { min(48, max(0, points)) }
    var spread: Double { 8 + sqrt(Double(min(196, max(0, points)))) * 4 }
    func adding(to events: [Self]) -> [Self] { Array((events + [self]).suffix(Self.maximumActive)) }
    static func finishing(_ token: UUID, in events: [Self]) -> [Self] { events.filter { $0.token != token } }
    var intensity: Double { maximum > 0 ? min(1, max(0, Double(points) / Double(maximum))) : 0 }
}

/// Deterministic individual point paths; independent of game state and authoritative scoring.
struct MountainPointParticle {
    let x: Double
    let y: Double
    let opacity: Double
    static func sample(index: Int, count: Int, progress: Double, startX: Double, startY: Double,
                       endX: Double, endY: Double, spread: Double) -> Self {
        let delay = count > 1 ? Double(index) / Double(count - 1) * 0.22 : 0
        let t = min(1, max(0, (progress - delay) / (1 - delay)))
        let travel = t * t * (3 - 2 * t)
        let fan = sin(.pi * t)
        let lane = sin(Double(index + 1) * 2.39996)
        return Self(x: startX + (endX - startX) * travel + fan * lane * spread,
                    y: startY + (endY - startY) * travel - fan * (24 + spread * (0.4 + abs(lane))),
                    opacity: progress < delay || t >= 1 ? 0 : min(1, t * 12) * min(1, (1 - t) * 10))
    }
}

struct MountainDisplaySnapshot: Sendable {
    let owner: UUID
    let game: MountainGame
    let names: [String]
    let symbols: [String]
    let computers: [Bool]
    let difficulty: ComputerDifficulty
    let lastMove: Int?
    let lastPoints: Int
    let paused: Bool
    var avatarStyles: [String] = []
    var photoIDs: [String?] = []
    var humanVictory: Bool { game.isOver && game.scores[0] != game.scores[1] && !computers[game.scores[0] > game.scores[1] ? 0 : 1] }
    static var design: Self {
        var game = MountainGame(size: 6, values: Array(1...36), startingLine: 2)
        for tile in [17, 35, 30, 0, 4, 28] { game.play(tile) }
        return Self(owner: UUID(uuidString: "00000000-0000-4000-8000-000000000001")!, game: game, names: ["Nathan", "Quinn"], symbols: ["leaf.fill", "pawprint.fill"], computers: [false, true], difficulty: .level1, lastMove: 28, lastPoints: 29, paused: false)
    }
}
