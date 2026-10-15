import Foundation

// The initial board and legal move history are the wire format. Never trust a received score.
struct MountainChallenge: Codable, Sendable, Identifiable, Equatable {
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

struct FriendRace: Codable, Sendable, Identifiable, Equatable {
    let id: String
    let title: String
    let names: [String]
    let challenge: MountainChallenge?
    let yourTurn: Bool
    let ended: Bool
    let updated: Date
    var problem: String? = nil

    var isValid: Bool {
        !id.isEmpty && id.utf8.count <= 256 && title.utf8.count <= 2_048 &&
        names.count == 2 && names.allSatisfy { !$0.isEmpty && $0.utf8.count <= 2_048 } &&
        (challenge == nil || challenge!.isValid) && (problem?.utf8.count ?? 0) <= 2_048 &&
        (!ended || !yourTurn)
    }
    func preservingProgress(from previous: Self?) -> Self {
        guard let previous, previous.id == id, let old = previous.challenge else { return self }
        if previous.ended && !ended { return previous }
        guard let new = challenge else {
            var retained = previous
            retained.problem = "Couldn't load this game. Refresh to try again."
            return retained
        }
        guard !new.continues(old) else { return self }
        if old.continues(new) { return previous }
        var retained = previous
        retained.problem = "The game changed. Refresh to try again."
        return retained
    }
}

// The phone derives the actor from Game Center. A watch never supplies a player ID.
struct MountainMoveRequest: Codable, Sendable, Equatable {
    let id: UUID
    let matchID: String
    let previous: MountainChallenge
    let tile: Int

    var isValid: Bool {
        !matchID.isEmpty && matchID.utf8.count <= 256 && previous.isValid && previous.game.canPlay(tile)
    }
    func applying(to current: MountainChallenge, player: String) throws -> MountainChallenge {
        guard isValid, current.isValid, current.continues(previous), current.moves.count == previous.moves.count else {
            throw MountainMatchError.changedTurn
        }
        var next = current
        guard next.play(tile, player: player) else { throw MountainMatchError.changedTurn }
        return next
    }
}

struct MountainFriendInbox: Codable, Sendable, Equatable {
    let version: Int
    let sequence: UInt64
    let player: String?
    let matches: [FriendRace]
    let updated: Date

    var isValid: Bool {
        version == 1 && sequence > 0 && (player == nil || (!player!.isEmpty && player!.utf8.count <= 256)) &&
        (player != nil || matches.isEmpty) && Set(matches.map(\.id)).count == matches.count &&
        matches.allSatisfy { race in
            race.isValid && (race.challenge == nil || race.challenge!.seat(for: player ?? "") != nil) &&
            (!race.yourTurn || race.challenge == nil || race.challenge!.seat(for: player ?? "") == race.challenge!.game.turn)
        }
    }
    func encoded() throws -> Data {
        guard isValid else { throw MountainMatchError.invalidData }
        let data = try JSONEncoder().encode(self)
        guard data.count <= 4_194_304 else { throw MountainMatchError.invalidData }
        return data
    }
    static func decode(_ data: Data) throws -> Self {
        guard data.count <= 4_194_304 else { throw MountainMatchError.invalidData }
        let result = try JSONDecoder().decode(Self.self, from: data)
        guard result.isValid else { throw MountainMatchError.invalidData }
        return result
    }
    // Phone sequence is durable across launches. An older delivery cannot roll a board back.
    func replaces(_ previous: Self?) -> Bool { isValid && sequence > (previous?.sequence ?? 0) }
}

struct MountainWatchRequest: Codable, Sendable {
    let version: Int
    let id: UUID
    let move: MountainMoveRequest?
    var matchID: String? = nil

    static func decode(_ data: Data) throws -> Self {
        guard data.count <= 40_000 else { throw MountainMatchError.invalidData }
        let request = try JSONDecoder().decode(Self.self, from: data)
        guard request.version == 1, request.move == nil || (request.move!.id == request.id && request.move!.isValid),
              request.matchID == nil || (request.move == nil && !request.matchID!.isEmpty && request.matchID!.utf8.count <= 256) else {
            throw MountainMatchError.invalidData
        }
        return request
    }
}

struct MountainWatchReply: Codable, Sendable {
    let requestID: UUID
    let accepted: Bool
    let sequence: UInt64
    let inbox: MountainFriendInbox?
    let error: String?

    func acknowledges(_ request: MountainWatchRequest) -> Bool {
        requestID == request.id && sequence > 0 && (inbox == nil || (inbox!.isValid && inbox!.sequence == sequence)) &&
        (!accepted || error == nil)
    }
}

struct MountainWatchReceipt: Codable, Sendable {
    let player: String
    let move: MountainMoveRequest
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
    var history: MountainHistory?
    var recorded = false
    var computerStarted = false
    var rolesChanged = false
    var learning: MountainLearningContext?

    init(size: Int, names: [String], computers: [Bool], difficulty: ComputerDifficulty, adjustment: Int, startingPlayer: Int? = nil) {
        self.names = names; self.computers = computers; self.difficulty = difficulty
        self.adjustment = min(2, max(-2, adjustment))
        computerStarted = computers.contains(false)
        game = MountainGame(size: size, firstPlayer: MountainGame.randomStartingPlayer(computers: computers, coin: startingPlayer))
        history = MountainHistory(initial: game)
    }
    var title: String { computers.contains(true) ? "You & \(difficulty.name)" : names.joined(separator: " & ") }
    var isValid: Bool {
        names.count == 2 && names.allSatisfy { !$0.isEmpty && $0.utf8.count <= 240 } &&
        computers.count == 2 && (-2...2).contains(adjustment) && game.isValid &&
        (history == nil || history!.matches(game)) &&
        (replay == nil || (replay!.before.isValid && replay!.before.canPlay(replay!.tileID) && replay!.before.size == game.size && replay!.before.moves < game.moves))
    }
}

// Friend transcripts already contain the genuine initial board and each legal choice.
extension MountainHistory {
    init?(challenge: MountainChallenge) {
        guard challenge.isValid else { return nil }
        let initial = MountainGame(size: challenge.size, values: challenge.values, startingLine: challenge.startingLine)
        self.init(initial: initial)
        var state = initial
        for tile in challenge.moves {
            guard record(tile, before: state), state.play(tile) else { return nil }
        }
        guard matches(challenge.game) else { return nil }
    }
}
