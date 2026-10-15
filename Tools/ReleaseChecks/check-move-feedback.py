#!/usr/bin/env python3
"""Exercise the actual move handler with overlapping, independently completed visual events."""
from pathlib import Path
import subprocess
import tempfile
root = Path(__file__).resolve().parents[2]
source = (root / 'Race to Dog Mountain/MountainViews.swift').read_text()
body = source.split('    private func move(_ id: Int, computer: Bool = false) {', 1)[1].split('\n    }', 1)[0]
harness = r'''
import Foundation
@MainActor final class Moves {
    var reduceMotion = false
    var resolution: UUID?
    var computers = [false, true]
    var game = MountainGame(size: 7, values: Array(1...49), startingLine: 0)
    var feedback: [MountainMoveFeedback] = []
    var history: MountainHistory?
    var moveIntensity = 0.0
    var lastComputerMove: MountainReplay?
    var lastPoints = 0
    var lastMove: Int?
    var difficulty = ComputerDifficulty.level1
    var saves = 0
    init() { history = MountainHistory(initial: game) }
    func recordWin() {}
    func persist() { saves += 1 }
    func move(_ id: Int, computer: Bool = false) {
BODY
    }
}
@main struct MoveFeedbackChecks {
    @MainActor static func main() {
        let live = Moves()
        var expected = live.game
        for _ in 0..<10 {
            guard let tile = live.game.legalMoves.first else { break }
            let computer = live.computers[live.game.turn]
            live.move(tile, computer: computer)
            expected.play(tile)
            assert(live.game.moves == expected.moves && live.game.scores == expected.scores)
            assert(live.history?.matches(live.game) == true && live.game.isValid)
            assert(live.feedback.count <= 4 && live.saves == live.game.moves)
            let count = live.feedback.count
            live.move(tile, computer: computer) // A used tile / pending AI hold is never scored again.
            assert(live.game.moves == expected.moves && live.feedback.count == count)
            live.resolution = nil
        }
        assert(live.feedback.count > 1, "Fixture must overlap human and AI feedback")
        let newer = live.feedback.last!, older = live.feedback.first!
        let score = live.game.scores, moves = live.game.moves
        live.feedback = MountainMoveFeedback.finishing(older.token, in: live.feedback)
        assert(live.feedback.contains(where: { $0.token == newer.token }))
        live.feedback = MountainMoveFeedback.finishing(older.token, in: live.feedback)
        assert(live.game.scores == score && live.game.moves == moves)
        live.feedback.removeAll(); live.reduceMotion = true
        if let tile = live.game.legalMoves.first {
            live.move(tile, computer: live.computers[live.game.turn])
            assert(live.feedback.isEmpty && live.game.moves == moves + 1 && live.history!.matches(live.game))
        }
        print("PASS: actual human/AI move handler scores once; overlapping capped flights finish independently; duplicate taps and visual completions cannot mutate scores; Reduce Motion preserves scoring without particles.")
    }
}
'''.replace('BODY', body)
with tempfile.TemporaryDirectory(prefix='mountain-move-feedback-') as temp:
    swift = Path(temp) / 'Moves.swift'; swift.write_text(harness)
    binary = Path(temp) / 'check'
    subprocess.run(['xcrun', 'swiftc', '-parse-as-library', str(root / 'Race to Dog Mountain/MountainGame.swift'), str(swift), '-o', str(binary)], check=True)
    subprocess.run([str(binary)], check=True)
