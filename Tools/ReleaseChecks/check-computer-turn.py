#!/usr/bin/env python3
"""Run the actual SwiftUI task body with its identity and isolated game state.

SwiftUI supplies cancellation when a task ID changes. This check simulates that
contract without opening the app or accessing real preferences.
"""
from pathlib import Path
import re
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]
source = (root / 'Race to Dog Mountain/MountainViews.swift').read_text()
match = re.search(r'\.task\(id: (.*?)\) \{\n(.*?)\n            \}\n            \.onChange', source, re.S)
assert match, 'Computer task extraction no longer matches production source'
identity, body = match.groups()
harness = r'''
import Foundation

final class UIApplication {
    enum State { case active, background }
    static let shared = UIApplication()
    var applicationState = State.active
}

@MainActor final class Turns {
    var foregroundNonce = 0
    var confirmExit = false
    var computers = [true, true]
    var game = MountainGame(size: 4, plusMode: false, values: Array(1...16), firstPlayer: 0, startingLine: 0)
    var task: Task<Void, Never>?
    var previousID: String?
    func move(_ id: Int) { _ = game.play(id) }
    func restartIfNeeded() {
        let nextID = IDENTITY
        guard nextID != previousID else { return }
        previousID = nextID
        task?.cancel()
        task = Task { await self.runActualBody() }
    }
    func runActualBody() async {
BODY
    }
}

@main struct ComputerTurnChecks {
    static func require(_ value: Bool, _ message: String) {
        guard value else { print("FAIL: \(message)"); exit(1) }
    }
    @MainActor static func main() async throws {
        let turns = Turns()
        turns.restartIfNeeded()
        try await Task.sleep(for: .milliseconds(50))
        turns.confirmExit = true
        turns.restartIfNeeded()
        try await Task.sleep(for: .milliseconds(650))
        require(turns.game.moves == 0, "Computer moved while exit confirmation was open")
        turns.confirmExit = false
        turns.restartIfNeeded()
        await turns.task?.value
        require(turns.game.moves == 1, "Cancel did not resume exactly one computer turn")

        // Changing the game starts the next turn. Backgrounding cancels it.
        turns.restartIfNeeded()
        try await Task.sleep(for: .milliseconds(50))
        UIApplication.shared.applicationState = .background
        turns.restartIfNeeded()
        try await Task.sleep(for: .milliseconds(650))
        require(turns.game.moves == 1, "Background app allowed a pending computer move")
        UIApplication.shared.applicationState = .active
        turns.foregroundNonce += 1
        turns.restartIfNeeded()
        await turns.task?.value
        require(turns.game.moves == 2, "Returning active did not resume the computer turn")
        turns.restartIfNeeded()
        turns.task?.cancel() // View dismissal cancels its task.
        await turns.task?.value
        require(turns.game.moves == 2, "Canceled view task moved after dismissal")
        print("Exit dialog pauses pending AI; Cancel resumes once; background/dismissed tasks cannot move: PASS")
    }
}
'''.replace('IDENTITY', identity).replace('BODY', body)
with tempfile.TemporaryDirectory(prefix='dog-mountain-turn-check-') as tmp:
    swift = Path(tmp) / 'ComputerTurnChecks.swift'
    swift.write_text(harness)
    executable = Path(tmp) / 'check'
    subprocess.run(['xcrun', 'swiftc', '-parse-as-library', str(root / 'Race to Dog Mountain/MountainGame.swift'), str(swift), '-o', str(executable)], check=True)
    subprocess.run([str(executable)], check=True)
