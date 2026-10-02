import Foundation

@main enum SocialMatchChecks {
    @MainActor static func main() throws {
        var first = MountainChallenge(size: 4, player: "row")
        let untouched = first
        assert(first.isValid && first.game.turn == 0)
        assert(!first.play(first.game.legalMoves[0], player: "column"))
        let rowTile = first.game.legalMoves[0]
        assert(first.play(rowTile, player: "row"))
        assert(!first.play(first.game.legalMoves[0], player: "row"))
        let received = try MountainChallenge.decodeMessage(first.messageURL())
        assert(received.id == first.id && received.game.scores == first.game.scores)
        assert(received.continues(untouched) && !untouched.continues(received))
        assert(received.messageSeat(senderIsLocal: true) == 0 && received.messageSeat(senderIsLocal: false) == 1)
        assert(untouched.messageSeat(senderIsLocal: true) == nil)
        assert(first.play(first.game.legalMoves[0], player: "column"))
        assert(first.messageSeat(senderIsLocal: true) == 1 && first.messageSeat(senderIsLocal: false) == 0)
        assert(first.columnPlayer == "column" && first.seat(for: "intruder") == nil)
        assert(!first.play(first.game.legalMoves[0], player: "intruder"))
        assert(!first.play(rowTile, player: "row"))
        let another = MountainChallenge(size: 4, player: "row")
        assert(another.id != first.id && another.game.moves == 0 && !another.continues(first))
        while !first.game.isOver {
            assert(first.play(first.game.legalMoves[0], player: first.game.turn == 0 ? "row" : "column"))
        }
        assert(first.isValid && first.game.isValid)
        assert(first.game.scores.reduce(0, +) + first.game.tiles.map(\.value).reduce(0, +) == 136)
        assert(!first.play(0, player: "row"))
        var json = try JSONSerialization.jsonObject(with: first.encoded()) as! [String: Any]
        for bad in [["size": 0], ["moves": [rowTile, rowTile]], ["version": 2], ["values": Array(repeating: 1, count: 16)], ["rowPlayer": "column"], ["moves": [-1]]] as [[String: Any]] {
            var corrupt = json
            bad.forEach { corrupt[$0.key] = $0.value }
            let data = try JSONSerialization.data(withJSONObject: corrupt)
            assert((try? MountainChallenge.decode(data)) == nil)
        }
        json["size"] = Int.max
        assert((try? MountainChallenge.decode(JSONSerialization.data(withJSONObject: json))) == nil)
        assert((try? MountainChallenge.decode(Data(repeating: 0, count: 32_769))) == nil)
        assert((try? MountainChallenge.decodeMessage(URL(string: "https://example.com/game")!)) == nil)

        // Watch commands use the unchanged transcript and the phone's authenticated actor.
        let commandID = UUID()
        let command = MountainMoveRequest(id: commandID, matchID: "first-match", previous: untouched, tile: rowTile)
        let advanced = try command.applying(to: untouched, player: "row")
        assert(advanced.moves == [rowTile] && untouched.moves.isEmpty)
        assert((try? command.applying(to: untouched, player: "column")) == nil)
        assert((try? command.applying(to: advanced, player: "row")) == nil, "A replayed/stale command must never append twice")
        assert((try? command.applying(to: another, player: "row")) == nil, "A command must not target a different board")
        let request = MountainWatchRequest(version: 1, id: commandID, move: command)
        let decodedRequest = try MountainWatchRequest.decode(JSONEncoder().encode(request))
        assert(decodedRequest.move == command)
        assert((try? MountainWatchRequest.decode(JSONEncoder().encode(MountainWatchRequest(version: 1, id: UUID(), move: command)))) == nil)
        assert((try? MountainWatchRequest.decode(Data(repeating: 0, count: 40_001))) == nil)
        let oldRace = FriendRace(id: "first-match", title: "Friend A", names: ["A", "B"], challenge: untouched, yourTurn: true, ended: false, updated: Date())
        let savedRace = FriendRace(id: oldRace.id, title: oldRace.title, names: oldRace.names, challenge: advanced, yourTurn: false, ended: false, updated: Date())
        let secondRace = FriendRace(id: "second-match", title: "Friend C", names: ["A", "C"], challenge: another, yourTurn: true, ended: false, updated: Date())
        assert(oldRace.preservingProgress(from: savedRace) == savedRace, "A late refresh must not roll a saved move back")
        assert(savedRace.preservingProgress(from: oldRace) == savedRace)
        let unreadable = FriendRace(id: savedRace.id, title: savedRace.title, names: savedRace.names, challenge: nil, yourTurn: false, ended: false, updated: Date())
        assert(unreadable.preservingProgress(from: savedRace).challenge == advanced)
        assert(unreadable.preservingProgress(from: savedRace).problem != nil)
        let completed = FriendRace(id: "finished-match", title: "Friend B", names: ["A", "B"], challenge: first, yourTurn: false, ended: true, updated: Date())
        let staleStatus = FriendRace(id: completed.id, title: completed.title, names: completed.names, challenge: first, yourTurn: false, ended: false, updated: Date())
        assert(staleStatus.preservingProgress(from: completed).ended, "A late same-board result must not reopen a completed game")
        let earlyInbox = MountainFriendInbox(version: 1, sequence: 1, player: "row", matches: [oldRace, secondRace], updated: Date())
        let nextInbox = MountainFriendInbox(version: 1, sequence: 2, player: "row", matches: [savedRace, secondRace], updated: Date())
        assert(nextInbox.replaces(earlyInbox) && !earlyInbox.replaces(nextInbox) && !nextInbox.replaces(nextInbox))
        assert(nextInbox.matches[1].challenge!.moves.isEmpty)
        let accepted = MountainWatchReply(requestID: commandID, accepted: true, sequence: 2, inbox: nextInbox, error: nil)
        assert(accepted.acknowledges(request))
        assert(!MountainWatchReply(requestID: UUID(), accepted: true, sequence: 2, inbox: nextInbox, error: nil).acknowledges(request))
        assert(!MountainWatchReply(requestID: commandID, accepted: true, sequence: 2, inbox: nextInbox, error: "Not saved").acknowledges(request))
        let emptyAccount = MountainFriendInbox(version: 1, sequence: 3, player: nil, matches: [], updated: Date())
        assert(emptyAccount.replaces(nextInbox))
        assert(!MountainFriendInbox(version: 1, sequence: 3, player: nil, matches: [savedRace], updated: Date()).isValid)
        assert(!MountainFriendInbox(version: 1, sequence: 3, player: "row", matches: [savedRace, savedRace], updated: Date()).isValid)

        let suite = "dog-social-check-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(try nextInbox.encoded(), forKey: "watchFriendInbox.v1")
        let reloadedInbox = try MountainFriendInbox.decode(UserDefaults(suiteName: suite)!.data(forKey: "watchFriendInbox.v1")!)
        assert(reloadedInbox == nextInbox && reloadedInbox.matches.count == 2)
        let receipts = [MountainWatchReceipt(player: "row", move: command)]
        defaults.set(try JSONEncoder().encode(receipts), forKey: "watchMoveReceipts.v1")
        let reloadedReceipts = try JSONDecoder().decode([MountainWatchReceipt].self, from: UserDefaults(suiteName: suite)!.data(forKey: "watchMoveReceipts.v1")!)
        assert(reloadedReceipts[0].player == "row" && reloadedReceipts[0].move == command)
        let library = MountainLibrary(defaults: defaults)
        var local = SavedMountainGame(size: 4, names: ["A", "B"], computers: [false, false], difficulty: .level6, adjustment: 0)
        let separate = SavedMountainGame(size: 4, names: ["C", "D"], computers: [false, true], difficulty: .level8, adjustment: 1)
        library.save(local); library.save(separate)
        let tile = local.game.legalMoves[0]
        local.game.play(tile); library.save(local)
        let restored = MountainLibrary(defaults: defaults)
        assert(restored.active.count == 2)
        assert(restored.games.first { $0.id == local.id }!.game.moves == 1)
        assert(restored.games.first { $0.id == separate.id }!.game.moves == 0)
        while !local.game.isOver { local.game.play(local.game.legalMoves[0]) }
        local.recorded = true; library.save(local)
        assert(library.active.count == 1 && library.finished.count == 1)
        assert(MountainLibrary(defaults: defaults).finished[0].recorded)
        defaults.set(Data("broken".utf8), forKey: "mountainGames.v1")
        let recovery = MountainLibrary(defaults: defaults)
        assert(recovery.error != nil && recovery.games.isEmpty)
        recovery.save(separate)
        assert(defaults.data(forKey: "mountainGames.v1.recovery") == Data("broken".utf8))
        print("Independent saves, legal two-player turns, wire validation, Watch command/reply validation, durable multi-game inbox/receipts, stale snapshot/command rejection, Messages URL roundtrip, result persistence and corruption recovery passed.")
    }
}
