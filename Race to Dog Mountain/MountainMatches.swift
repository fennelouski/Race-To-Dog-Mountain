import Foundation

// The initial board and legal move history are the wire format. Never trust a received score.
struct MountainChallenge: Codable, Sendable, Identifiable {
    let version: Int
    let id: UUID
    let size: Int
    let values: [Int]
    let startingLine: Int
    let rowPlayer: String
    private(set) var columnPlayer: String?
    private(set) var moves: [Int]

    init(size: Int = 6, player: String) {
        let initial = MountainGame(size: size)
        version = 1; id = UUID(); self.size = initial.size
        values = initial.tiles.map(\.value); startingLine = initial.row
        rowPlayer = player; moves = []
    }
    var game: MountainGame {
        var result = MountainGame(size: size, values: values, startingLine: startingLine)
        for tile in moves { result.play(tile) }
        return result
    }
    func seat(for player: String) -> Int? {
        if player == rowPlayer { return 0 }
        if columnPlayer == nil || columnPlayer == player { return 1 }
        return nil
    }
    @discardableResult mutating func play(_ tile: Int, player: String) -> Bool {
        guard let seat = seat(for: player), seat == game.turn, game.canPlay(tile) else { return false }
        if seat == 1 { columnPlayer = player }
        moves.append(tile)
        return true
    }
    var isValid: Bool {
        guard version == 1, (4...14).contains(size), (0..<size).contains(startingLine),
              !rowPlayer.isEmpty, rowPlayer.utf8.count <= 256,
              columnPlayer == nil || (!columnPlayer!.isEmpty && columnPlayer != rowPlayer && columnPlayer!.utf8.count <= 256) else { return false }
        let count = size * size
        guard values.count == count, Set(values) == Set(1...count), moves.count <= count,
              moves.count < 2 || columnPlayer != nil else { return false }
        var result = MountainGame(size: size, values: values, startingLine: startingLine)
        for tile in moves { guard result.play(tile) else { return false } }
        return true
    }
    func encoded() throws -> Data { try JSONEncoder().encode(self) }
    static func decode(_ data: Data) throws -> Self {
        guard data.count <= 32_768 else { throw MountainMatchError.invalidData }
        let result = try JSONDecoder().decode(Self.self, from: data)
        guard result.isValid else { throw MountainMatchError.invalidData }
        return result
    }
    // This URL is data carried by Messages, not a hosted service or an invitation sent by the app.
    func messageURL() throws -> URL {
        guard let url = URL(string: "data:application/vnd.dogmountain.match+json;base64," + (try encoded()).base64EncodedString()) else { throw MountainMatchError.invalidData }
        return url
    }
    static func decodeMessage(_ url: URL) throws -> Self {
        let prefix = "data:application/vnd.dogmountain.match+json;base64,"
        let text = url.absoluteString
        guard text.utf8.count <= 48_000, text.hasPrefix(prefix),
              let data = Data(base64Encoded: String(text.dropFirst(prefix.count))) else { throw MountainMatchError.invalidData }
        return try decode(data)
    }
    func continues(_ previous: Self) -> Bool {
        id == previous.id && version == previous.version && size == previous.size && values == previous.values &&
        startingLine == previous.startingLine && rowPlayer == previous.rowPlayer &&
        (previous.columnPlayer == nil || columnPlayer == previous.columnPlayer) && moves.starts(with: previous.moves)
    }
    // Messages participant UUIDs differ on each device. Infer the local seat from the last sender.
    func messageSeat(senderIsLocal: Bool) -> Int? {
        guard !moves.isEmpty else { return nil }
        let senderSeat = (moves.count - 1) % 2
        return senderIsLocal ? senderSeat : 1 - senderSeat
    }
}

enum MountainMatchError: LocalizedError {
    case invalidData, changedTurn, unavailable
    var errorDescription: String? {
        switch self {
        case .invalidData: "This game can't be opened. Ask your friend to start a new one."
        case .changedTurn: "The game changed. Refresh before choosing your next move."
        case .unavailable: "This game isn't ready yet. Refresh to try again."
        }
    }
}

struct SavedMountainGame: Codable, Identifiable {
    var id = UUID()
    var updatedAt = Date()
    let names: [String]
    let difficulty: ComputerDifficulty
    var computers: [Bool]
    var adjustment: Int
    var game: MountainGame
    var replay: MountainReplay?
    var recorded = false
    var computerStarted = false
    var rolesChanged = false

    init(size: Int, names: [String], computers: [Bool], difficulty: ComputerDifficulty, adjustment: Int) {
        self.names = names; self.computers = computers; self.difficulty = difficulty
        self.adjustment = min(2, max(-2, adjustment))
        game = MountainGame(size: size, firstPlayer: MountainGame.startingPlayer(computers: computers))
    }
    var title: String { computers.contains(true) ? "You & \(difficulty.name)" : names.joined(separator: " & ") }
    var isValid: Bool {
        names.count == 2 && names.allSatisfy { !$0.isEmpty && $0.utf8.count <= 240 } &&
        computers.count == 2 && (-2...2).contains(adjustment) && game.isValid &&
        (replay == nil || (replay!.before.isValid && replay!.before.canPlay(replay!.tileID) && replay!.before.size == game.size && replay!.before.moves < game.moves))
    }
}
