import Foundation

@main enum WatchMatchCheck {
    static func main() {
        let domain = "dog-mountain-watch-check.\(UUID())"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        var match = WatchMatch(size: 4, difficulty: .level16, computers: [false, true], defaults: defaults)
        assert(match.game.turn == 0 && !match.waitingForStart)
        assert(!match.canComputerMove(active: true, paused: false))
        assert(match.play(match.game.legalMoves[0], defaults: defaults))
        assert(match.canComputerMove(active: true, paused: false))
        assert(!match.canComputerMove(active: false, paused: false) && !match.canComputerMove(active: true, paused: true))
        let move = match.game.computerMove(difficulty: match.difficulty, roll: 0)!
        assert(!match.play(move, defaults: defaults))
        assert(match.play(move, computer: true, defaults: defaults))
        assert(match.replay!.after.moves == match.game.moves)
        let saved = WatchMatch.restore(defaults: defaults)!
        assert(saved.id == match.id && saved.game.moves == match.game.moves && saved.game.scores == match.game.scores)
        assert(saved.replay?.tileID == move)
        while !match.game.isOver {
            assert(match.play(match.game.legalMoves[0], computer: match.computers[match.game.turn], defaults: defaults))
        }
        assert(match.recorded)
        let next = WatchMatch(size: 4, difficulty: .level16, computers: [false, true], defaults: defaults)
        assert(next.adjustment == (match.game.scores[0] == match.game.scores[1] ? 0 : match.game.scores[0] > match.game.scores[1] ? 1 : -1))
        var demo = WatchMatch(size: 4, difficulty: .level6, computers: [true, true], defaults: defaults)
        assert(demo.waitingForStart && !demo.canComputerMove(active: true, paused: false))
        assert(!demo.play(demo.game.legalMoves[0], computer: true, defaults: defaults))
        demo.startComputer()
        assert(demo.canComputerMove(active: true, paused: false))
        assert(WatchMatch(size: 4, difficulty: .level6, computers: [true, false], defaults: defaults).game.turn == 1)
        demo.save(defaults: defaults)
        var json = try! JSONSerialization.jsonObject(with: defaults.data(forKey: WatchMatch.saveKey)!) as! [String: Any]
        var game = json["game"] as! [String: Any]; game["size"] = 0; json["game"] = game
        defaults.set(try! JSONSerialization.data(withJSONObject: json), forKey: WatchMatch.saveKey)
        assert(WatchMatch.restore(defaults: defaults) == nil)
        print("Watch saves, corruption guard, human starts, computer gates, pause, replay and result adaptation passed.")
    }
}
