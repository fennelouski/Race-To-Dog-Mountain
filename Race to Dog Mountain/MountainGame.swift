import Foundation

struct MountainGame {
    struct Tile: Identifiable {
        let id: Int
        var value: Int
        var owner: Int
    }
    let size: Int
    let plusMode: Bool
    private(set) var tiles: [Tile]
    private(set) var scores = [0, 0]
    private(set) var turn: Int
    private(set) var row: Int
    private(set) var column: Int
    private(set) var moves = 0

    init(size: Int, plusMode: Bool, values: [Int]? = nil, firstPlayer: Int? = nil, startingLine: Int? = nil) {
        self.size = min(max(size, 4), 14)
        self.plusMode = plusMode
        let side = self.size
        let count = side * side
        let numbers = values?.count == count ? values! : Array(1...count).shuffled()
        tiles = numbers.enumerated().map { Tile(id: $0.offset, value: $0.element, owner: ($0.offset / side + $0.offset % side) % 2) }
        turn = firstPlayer.map { min(max($0, 0), 1) } ?? Int.random(in: 0...1)
        row = min(max(startingLine ?? Int.random(in: 0..<self.size), 0), self.size - 1)
        column = row
    }

    func canPlay(_ id: Int) -> Bool {
        guard tiles.indices.contains(id), tiles[id].value > 0 else { return false }
        return plusMode ? tiles[id].owner == turn : (turn == 0 ? id / size == row : id % size == column)
    }
    var legalMoves: [Int] { tiles.filter { canPlay($0.id) }.map(\.id) }
    var isOver: Bool { legalMoves.isEmpty }

    func neighbors(of id: Int) -> [Int] {
        guard tiles.indices.contains(id) else { return [] }
        let r = id / size, c = id % size
        return [(r - 1, c), (r + 1, c), (r, c - 1), (r, c + 1)]
            .filter { (0..<size).contains($0.0) && (0..<size).contains($0.1) }
            .map { $0.0 * size + $0.1 }
    }

    @discardableResult mutating func play(_ id: Int) -> Bool {
        guard canPlay(id) else { return false }
        scores[turn] += tiles[id].value
        if plusMode {
            for index in neighbors(of: id) + [id] { tiles[index].owner = 1 - tiles[index].owner }
        } else if turn == 0 { column = id % size }
        else { row = id / size }
        tiles[id].value = 0
        turn = 1 - turn
        moves += 1
        return true
    }

    func computerMove() -> Int? {
        legalMoves.max { weight($0) < weight($1) }
    }
    private func weight(_ id: Int) -> Int {
        if plusMode {
            return tiles[id].value * 4 + neighbors(of: id).reduce(0) { $0 + (tiles[$1].owner == turn ? -tiles[$1].value : tiles[$1].value) }
        }
        var next = self
        next.play(id)
        return tiles[id].value - (next.legalMoves.map { next.tiles[$0].value }.max() ?? 0)
    }
}

#if DOGMOUNTAIN_CHECKS
@main enum MountainGameCheck {
    static func main() {
        var classic = MountainGame(size: 4, plusMode: false, values: Array(1...16), firstPlayer: 0, startingLine: 0)
        assert(!classic.play(4))
        assert(classic.play(2) && classic.scores == [3, 0] && classic.turn == 1)
        assert(!classic.play(2) && !classic.play(5))
        assert(classic.play(14) && classic.scores == [3, 15] && classic.row == 3)
        var plus = MountainGame(size: 4, plusMode: true, values: Array(1...16), firstPlayer: 0)
        assert(!plus.play(1) && plus.play(0))
        assert(plus.tiles[1].owner == 0 && plus.tiles[4].owner == 0 && plus.tiles[5].owner == 0)
        for mode in [false, true] {
            var game = MountainGame(size: 6, plusMode: mode)
            while let move = game.computerMove() { assert(game.play(move)); assert(game.moves <= 36) }
            assert(game.isOver && game.scores.reduce(0, +) + game.tiles.map(\.value).reduce(0, +) == 666)
        }
        print("Classic, Plus, illegal/repeated moves, AI completion and score conservation passed.")
    }
}
#endif
