import Foundation

@main enum NativeFinishChecks {
    static func require(_ value: @autoclosure () -> Bool, _ message: String) {
        guard value() else { fatalError(message) }
    }
    static func main() throws {
        let defaults = MountainExperience.defaults
        require(MountainExperience.isQAActive, "Checks must use a DEBUG UUID store")
        require(MountainExperience.animationsEnabled && MountainExperience.hapticsEnabled, "Missing effects keys must default on")
        defaults.set(false, forKey: "animationsEnabled")
        require(!MountainExperience.animationsEnabled && MountainExperience.hapticsEnabled, "Motion and haptics must be independent")
        defaults.set(false, forKey: "hapticsEnabled")
        require(!MountainExperience.hapticsEnabled, "A saved false must remain false")
        for value in [-1.0, 0.2, 0.4, 0.7, 1.2, 8.0] {
            defaults.set(value, forKey: "computerMoveDuration")
            require(MountainExperience.computerDuration >= 0.4 && MountainExperience.computerDuration <= 1.2, "Computer transition duration must remain bounded above 350ms")
        }
        for size in [4, 6, 14] {
            var game = MountainGame(size: size, values: Array(1...(size * size)), firstPlayer: 1, startingLine: 0)
            var history = MountainHistory(initial: game)
            require(!history.record(-1, before: game), "Illegal move must not enter history")
            while let tile = game.legalMoves.first {
                require(history.record(tile, before: game), "Every actual legal move must record")
                require(game.play(tile), "Actual move must play")
                require(history.matches(game), "Transcript must reproduce every board, score, player and next line")
            }
            require(history.states?.count == game.moves + 1 && game.isOver, "Export states must include start and actual finish")
            let decoded = try JSONDecoder().decode(MountainHistory.self, from: JSONEncoder().encode(history))
            require(decoded.matches(game), "Persisted history must reproduce actual finish")
            require(history.states!.count <= 197, "Largest board must obey export frame bound")
            var saved = SavedMountainGame(size: size, names: ["First", "Second"], computers: [false, false], difficulty: .level6, adjustment: 0)
            saved.game = game; saved.history = history
            require(saved.isValid, "Recorded actual save should be valid")
            var legacy = try JSONSerialization.jsonObject(with: JSONEncoder().encode(saved)) as! [String: Any]
            legacy.removeValue(forKey: "history")
            let restored = try JSONDecoder().decode(SavedMountainGame.self, from: JSONSerialization.data(withJSONObject: legacy))
            require(restored.isValid && restored.history == nil, "Legacy saves must load without inventing history")
            var invalid = saved
            invalid.history = MountainHistory(initial: MountainGame(size: size))
            require(!invalid.isValid, "Mismatching transcript must fail validation")
            var historyJSON = try JSONSerialization.jsonObject(with: JSONEncoder().encode(history)) as! [String: Any]
            historyJSON["choices"] = [size * size + 1]
            let corrupt = try JSONDecoder().decode(MountainHistory.self, from: JSONSerialization.data(withJSONObject: historyJSON))
            require(corrupt.states == nil, "Corrupt transcript must never produce frames")
        }
        var friend = MountainChallenge(size: 4, player: "Row")
        while let tile = friend.game.legalMoves.first {
            require(friend.play(tile, player: friend.game.turn == 0 ? "Row" : "Column"), "Friend transcript actual legal move must play")
        }
        let friendHistory = MountainHistory(challenge: friend)
        require(friendHistory?.matches(friend.game) == true && friendHistory?.choices == friend.moves, "Friend export must use exactly the validated real wire history")
        print("Default-on independent saved effects, bounded computer duration, real transcript at 4/6/14, persistence, legacy and corrupt-history checks: PASS")
    }
}
