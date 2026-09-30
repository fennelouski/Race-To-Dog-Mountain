import SwiftUI

struct MountainActions {
    var newGame: () -> Void
    var options: (() -> Void)? = nil
    var rules: (() -> Void)? = nil
    var replay: (() -> Void)? = nil
    var close: (() -> Void)? = nil
}

private struct MountainActionsKey: FocusedValueKey {
    typealias Value = MountainActions
}

extension FocusedValues {
    var mountainActions: MountainActions? {
        get { self[MountainActionsKey.self] }
        set { self[MountainActionsKey.self] = newValue }
    }
}

@main struct MountainMacApp: App {
    var body: some Scene {
        WindowGroup("Race to Dog Mountain") {
            MountainHome().frame(minWidth: 620, minHeight: 660)
        }
        .defaultSize(width: 1000, height: 820)
        .windowResizability(.contentMinSize)
        .commands { MountainCommands() }
    }
}

private struct MountainCommands: Commands {
    @FocusedValue(\.mountainActions) private var actions
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Game") { actions?.newGame() }
                .keyboardShortcut("n").disabled(actions == nil)
        }
        CommandMenu("Game") {
            Button("Replay Computer Move") { actions?.replay?() }
                .keyboardShortcut("r").disabled(actions?.replay == nil)
            Button("Players & Board…") { actions?.options?() }
                .keyboardShortcut(",").disabled(actions?.options == nil)
            Button("Leave Game…") { actions?.close?() }
                .keyboardShortcut("w", modifiers: [.command, .shift]).disabled(actions?.close == nil)
        }
        CommandGroup(replacing: .help) {
            Button("How to Play") { actions?.rules?() }.disabled(actions?.rules == nil)
        }
    }
}
