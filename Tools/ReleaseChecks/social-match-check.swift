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

        let suite = "dog-social-check-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
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
        print("Independent saves, legal two-player turns, wire validation, stale history, Messages URL roundtrip, result persistence and corruption recovery passed.")
    }
}
