import Foundation

@main struct AvatarMotionChecks {
    static func main() {
        var game = MountainGame(size: 4, values: Array(1...16), startingLine: 0)
        let initial = MountainAvatarActivity(game: game, player: 0)
        precondition(initial.cue(after: nil) == .enter)
        let original = game
        precondition(game.play(game.legalMoves.last!))
        let scored = MountainAvatarActivity(game: game, player: 0, lastMove: 3)
        precondition(scored.cue(after: initial) == .score)
        precondition(scored.look == 1 && !scored.isTurn)
        let watching = MountainAvatarActivity(game: game, player: 1)
        precondition(watching.cue(after: .init(game: original, player: 1)) == .attention)
        precondition(initial.cue(after: scored) == .attention, "Undo cannot celebrate a score")
        var paused = scored; paused.paused = true
        precondition(paused.cue(after: initial) == .settle)
        let still = MountainAvatarPose.sample(activity: paused, cue: .win, progress: 0)
        precondition(still == MountainAvatarPose.sample(activity: paused, cue: .enter, progress: 0.7))
        let start = MountainAvatarPose.sample(activity: initial, cue: .enter, progress: 0)
        let end = MountainAvatarPose.sample(activity: initial, cue: .enter, progress: 1)
        precondition(start.position.x < -2 && start.position.z < -0.5)
        precondition(abs(end.position.x) < 0.1 && abs(end.position.z) < 0.2)
        precondition(end.stride == 0 && end.roll == 0)
        for cue in [MountainAvatarCue.enter, .score, .win, .finish, .attention, .settle] {
            for tick in 0...120 {
                let pose = MountainAvatarPose.sample(activity: scored, cue: cue, progress: Float(tick) / 120)
                precondition(pose.position.x.isFinite && pose.position.y.isFinite && pose.position.z.isFinite)
                precondition(pose.yaw.isFinite && abs(pose.roll) <= 0.1)
                if cue != .enter { precondition(abs(pose.position.x) < 0.3 && pose.position.y < 0.2) }
            }
        }
        var outcomeGame = MountainGame(size: 4,
            values: [11, 15, 6, 2, 10, 3, 4, 12, 14, 8, 9, 5, 1, 7, 16, 13],
            startingLine: 0)
        let before = MountainAvatarActivity(game: outcomeGame, player: 0)
        while let tile = outcomeGame.legalMoves.max(by: {
            outcomeGame.tiles[$0].value < outcomeGame.tiles[$1].value
        }) { precondition(outcomeGame.play(tile)) }
        precondition(outcomeGame.isOver && outcomeGame.scores == [74, 62],
            "The deterministic outcome fixture must produce a winner")
        for player in 0...1 {
            let final = MountainAvatarActivity(game: outcomeGame, player: player)
            precondition(final.cue(after: before) == (final.outcome == .won ? .win : .finish))
        }
        precondition(original.moves == 0 && original.scores == [0, 0], "Sampling animation cannot mutate a game")
        print("PASS: avatar entrance/depth, own-score and opponent-turn reactions, end-game outcomes, paused still poses, undo without celebration and 726 bounded motion samples; game state remains independent.")
    }
}
