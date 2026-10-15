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
record = source.split('    private func recordWin() {', 1)[1].split('\n    }\n}', 1)[0]
record = record.replace('UserDefaults.standard', 'preferences')
harness = r'''
import Foundation

final class UIApplication {
    enum State { case active, inactive, background }
    static let shared = UIApplication()
    var applicationState = State.active
}

@MainActor enum MountainPlatform {
    static var isActive: Bool { UIApplication.shared.applicationState == .active }
}

@MainActor final class Turns {
    var foregroundNonce = 0
    var confirmExit = false
    var computerStarted = false
    var replaying = false
    var recorded = false
    var rolesChanged = false
    var savedID = UUID()
    var learning: MountainLearningContext?
    lazy var learningStore: MountainLearningStore? = MountainLearningStore(defaults: preferences)
    let names = ["Test first", "Test second"]
    let preferences = UserDefaults(suiteName: "dog-mountain-check-" + UUID().uuidString)!
    var difficulty = ComputerDifficulty.level6
    var matchAdjustment = 0
    var waitingForStart: Bool { game.moves == 0 && computers[game.turn] && !computerStarted }
    var computers = [true, true]
    var game = MountainGame(size: 4, values: Array(1...16), firstPlayer: 0, startingLine: 0)
    var task: Task<Void, Never>?
    var previousID: String?
    func move(_ id: Int, computer: Bool = false) { _ = game.play(id) }
    func restartIfNeeded() {
        let nextID = IDENTITY
        guard nextID != previousID else { return }
        previousID = nextID
        task?.cancel()
        task = Task { await self.runActualBody() }
    }
    func recordWin() {
RECORD
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
        await turns.task?.value
        require(turns.game.moves == 0, "Computer started before Play")
        turns.computerStarted = true
        turns.restartIfNeeded()
        try await Task.sleep(for: .milliseconds(50))
        turns.confirmExit = true
        turns.restartIfNeeded()
        try await Task.sleep(for: .milliseconds(850))
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
        try await Task.sleep(for: .milliseconds(850))
        require(turns.game.moves == 1, "Background app allowed a pending computer move")
        UIApplication.shared.applicationState = .active
        turns.foregroundNonce += 1
        turns.restartIfNeeded()
        await turns.task?.value
        require(turns.game.moves == 2, "Returning active did not resume the computer turn")
        turns.restartIfNeeded()
        try await Task.sleep(for: .milliseconds(50))
        UIApplication.shared.applicationState = .inactive
        try await Task.sleep(for: .milliseconds(850))
        require(turns.game.moves == 2, "Inactive app allowed a pending computer move")
        UIApplication.shared.applicationState = .active
        turns.foregroundNonce += 1
        turns.restartIfNeeded()
        await turns.task?.value
        require(turns.game.moves == 3, "Returning from inactive did not resume the computer turn")
        turns.restartIfNeeded()
        try await Task.sleep(for: .milliseconds(50))
        turns.replaying = true
        turns.restartIfNeeded()
        try await Task.sleep(for: .milliseconds(850))
        require(turns.game.moves == 3, "Replay allowed a pending live computer turn")
        turns.replaying = false
        turns.restartIfNeeded()
        await turns.task?.value
        require(turns.game.moves == 4, "Closing replay did not resume exactly one computer turn")
        turns.restartIfNeeded()
        turns.task?.cancel() // View dismissal cancels its task.
        await turns.task?.value
        require(turns.game.moves == 4, "Canceled view task moved after dismissal")
        let result = Turns()
        result.game = MountainGame(size: 4, values: [100] + Array(2...16), firstPlayer: 0, startingLine: 0)
        while !result.game.isOver { result.game.play(result.game.legalMoves[0]) }
        require(result.game.scores[0] != result.game.scores[1], "Result check needs an unequal score")
        let winner = result.game.scores[0] > result.game.scores[1] ? 0 : 1
        result.computers = [true, true]
        result.computers[winner] = false
        let key = MountainLearningStore.key(name: "Test human", size: 4, seat: 0)
        result.learning = result.learningStore!.begin(key: key)
        result.recordWin()
        require(result.learningStore!.learning(for: key).recent == [.win], "Human win was not recorded")
        result.recordWin()
        require(result.learningStore!.learning(for: key).recent == [.win], "Result trained twice")
        result.recorded = false; result.savedID = UUID()
        result.computers = result.computers.map { !$0 }
        result.recordWin()
        require(result.learningStore!.learning(for: key).recent == [.win, .loss], "Human loss was not recorded")
        result.recorded = false; result.savedID = UUID(); result.rolesChanged = true
        result.recordWin()
        require(result.learningStore!.learning(for: key).recent.count == 2, "Changed roles trained learning")
        result.recorded = false; result.savedID = UUID(); result.rolesChanged = false; result.computers = [true, true]
        result.recordWin()
        require(result.learningStore!.learning(for: key).recent.count == 2, "Computer-only game trained learning")
        result.recorded = false; result.savedID = UUID(); result.computers = [false, false]
        result.recordWin()
        require(result.learningStore!.learning(for: key).recent.count == 2, "Human-only game trained learning")
        result.recorded = false; result.savedID = UUID(); result.computers = [false, true]; result.learning = nil
        result.recordWin()
        require(result.learningStore!.learning(for: key).recent.count == 2, "Manual game trained learning")
        result.recorded = false; result.learning = result.learningStore!.begin(key: key)
        result.game = MountainGame(size: 4, values: Array(1...16), startingLine: 0)
        result.recordWin()
        require(!result.recorded && result.learningStore!.learning(for: key).recent.count == 2, "Unfinished game trained learning")
        print("Completed outcomes train once; changed roles, demos, human-only, manual and abandoned games do not train: PASS")
        print("Play gates computer starts; replay and exit dialog pause pending AI; Cancel resumes once; inactive/background/dismissed tasks cannot move: PASS")
    }
}
'''.replace('IDENTITY', identity).replace('BODY', body).replace('RECORD', record)
with tempfile.TemporaryDirectory(prefix='dog-mountain-turn-check-') as tmp:
    swift = Path(tmp) / 'ComputerTurnChecks.swift'
    swift.write_text(harness)
    executable = Path(tmp) / 'check'
    subprocess.run(['xcrun', 'swiftc', '-parse-as-library', '-target', subprocess.check_output(['uname', '-m'], text=True).strip() + '-apple-macos14.0', str(root / 'Race to Dog Mountain/MountainGame.swift'), str(root / 'Race to Dog Mountain/MountainMatches.swift'), str(root / 'Race to Dog Mountain/MountainLibrary.swift'), str(swift), '-o', str(executable)], check=True)
    subprocess.run([str(executable)], check=True)
