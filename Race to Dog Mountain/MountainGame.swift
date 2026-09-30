import Foundation

enum ComputerDifficulty: Int, CaseIterable, Identifiable, Sendable {
    case level1, level2, level3, level4, level5, level6, level7, level8
    case level9, level10, level11, level12, level13, level14, level15, level16
    var id: Int { rawValue }
    var name: String { ["Quinn", "Milo", "June", "Theo", "Amara", "Finn", "Leila", "Oscar", "Nia", "Hugo", "Sana", "Ezra", "Inez", "Kai", "Zuri", "Avery"][rawValue] }
    var title: String { "Level \(rawValue + 1)" }
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

struct MountainGame: Sendable {
    struct Tile: Identifiable, Sendable {
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

    func computerMove(difficulty: ComputerDifficulty = .level6, adjustment: Int = 0, roll: Double? = nil) -> Int? {
        let ranked = legalMoves.map { (id: $0, value: evaluated($0, depth: difficulty.depth, branches: difficulty.branches)) }
            .sorted { $0.value > $1.value }.map(\.id)
        guard let best = ranked.first else { return nil }
        let accuracy = min(1, max(0, difficulty.accuracy + Double(min(2, max(-2, adjustment))) * 0.0125))
        if (roll ?? Double.random(in: 0..<1)) < accuracy || ranked.count == 1 { return best }
        // A softer opponent sometimes picks another promising route, not an illegal move.
        let alternatives = Array(ranked.dropFirst().prefix(difficulty.rawValue < 4 ? ranked.count : 3))
        return alternatives.randomElement() ?? best
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

struct MountainReplay: Sendable {
    let before: MountainGame
    let tileID: Int
    let difficulty: ComputerDifficulty
    var after: MountainGame {
        var result = before
        result.play(tileID)
        return result
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
