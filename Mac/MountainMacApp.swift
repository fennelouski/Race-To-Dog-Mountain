import SwiftUI
import AppKit

struct MountainActions {
    var newGame: () -> Void
    var options: (() -> Void)? = nil
    var rules: (() -> Void)? = nil
    var replay: (() -> Void)? = nil
    var close: (() -> Void)? = nil
    var swap: (() -> Void)? = nil
    var history: (() -> Void)? = nil
    var invite: (() -> Void)? = nil
    var find: (() -> Void)? = nil
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
    // AppKit's automatic ⌃⌘F item is replaced by our ⇧⌘F one, so the View menu lists it once.
    init() { UserDefaults.standard.set(false, forKey: "NSFullScreenMenuItemEverywhere") }
    var body: some Scene {
        WindowGroup("Tally Tangle") {
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
        CommandGroup(after: .textEditing) {
            Button("Find Game…") { actions?.find?() }
                .keyboardShortcut("f").disabled(actions?.find == nil)
        }
        CommandMenu("Game") {
            Button("Replay Computer Move") { actions?.replay?() }
                .keyboardShortcut("r").disabled(actions?.replay == nil)
            Button("Switch Players") { actions?.swap?() }
                .keyboardShortcut("s", modifiers: [.command, .shift]).disabled(actions?.swap == nil)
            Divider()
            Button("History") { actions?.history?() }
                .keyboardShortcut("y").disabled(actions?.history == nil)
            Button("Invite a Friend") { actions?.invite?() }
                .keyboardShortcut("i").disabled(actions?.invite == nil)
            Divider()
            Button("Settings…") { actions?.options?() }
                .keyboardShortcut(",").disabled(actions?.options == nil)
            Button("Leave Game") { actions?.close?() }
                .keyboardShortcut("w", modifiers: [.command, .shift]).disabled(actions?.close == nil)
        }
        CommandGroup(after: .toolbar) {
            Button("Toggle Full Screen") { NSApp.keyWindow?.toggleFullScreen(nil) }
                .keyboardShortcut("f", modifiers: [.command, .shift])
        }
        CommandGroup(replacing: .help) {
            Button("How to Play") { actions?.rules?() }
                .keyboardShortcut("?").disabled(actions?.rules == nil)
        }
    }
}
