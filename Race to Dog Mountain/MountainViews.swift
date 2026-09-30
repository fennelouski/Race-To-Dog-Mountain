import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

@MainActor private enum MountainPlatform {
    static var isActive: Bool {
#if os(macOS)
        NSApplication.shared.isActive
#else
        UIApplication.shared.applicationState == .active
#endif
    }
    static var didBecomeActive: Notification.Name {
#if os(macOS)
        NSApplication.didBecomeActiveNotification
#else
        UIApplication.didBecomeActiveNotification
#endif
    }
}

#if os(iOS)

@objc(DMModernSceneDelegate)
final class MountainSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIHostingController(rootView: MountainHome())
        window.makeKeyAndVisible()
        self.window = window
    }
}

#endif

private struct MountainButton: ButtonStyle {
    var prominent = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.horizontal, 22).padding(.vertical, 18)
#if os(visionOS)
            .frame(minHeight: 60)
#else
            .frame(minHeight: 56)
#endif
            .foregroundStyle(prominent ? MountainStyle.ink : MountainStyle.cream)
            .background(prominent ? MountainStyle.gold : MountainStyle.cream.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(prominent ? 0.22 : 0), radius: 12, x: 0, y: 8)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.65), value: configuration.isPressed)
            .mountainHover()
    }
}

private struct MountainTileButton: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.9 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct MountainHome: View {
    @AppStorage("player1Name") private var firstName = "Player 1"
    @AppStorage("player2Name") private var secondName = "Player 2"
    @AppStorage("player1AI") private var firstAI = false
    @AppStorage("player2AI") private var secondAI = true
    @AppStorage("complexity") private var size = 6
    @AppStorage("computerLevel") private var computerLevel = 5
    @AppStorage("computerAdjustment") private var computerAdjustment = 0
    @AppStorage("computerDialogue") private var computerDialogue = false
    @State private var playing = false
    @State private var options = false
    @State private var rules = false
    @State private var history = [0, 0]
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Group {
#if os(macOS) || os(visionOS)
            if playing {
                MountainGameView(size: size, names: names, computers: [firstAI, secondAI], difficulty: difficulty, adjustment: computerAdjustment, onLeave: { playing = false; refreshHistory() })
            } else {
#if os(macOS)
                home.focusedSceneValue(\.mountainActions, MountainActions(newGame: { playing = true }, options: { options = true }, rules: { rules = true }))
#else
                visionHome
#endif
            }
#else
            home.fullScreenCover(isPresented: $playing, onDismiss: refreshHistory) {
                MountainGameView(size: size, names: names, computers: [firstAI, secondAI], difficulty: difficulty, adjustment: computerAdjustment)
            }
#endif
        }
        .sheet(isPresented: $options, onDismiss: refreshHistory) { playerOptions.mountainSheetSize() }
        .sheet(isPresented: $rules) { MountainRules().mountainSheetSize() }
        .onAppear { size = min(max(size, 4), 14); refreshHistory() }
        .onChange(of: firstName) { refreshHistory() }
        .onChange(of: secondName) { refreshHistory() }
    }

    private var home: some View {
        GeometryReader { geometry in
            ZStack {
                MountainScenery(active: !playing && !options && !rules)
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        HStack {
                            Image(systemName: "pawprint.fill").font(.title).foregroundStyle(MountainStyle.gold).accessibilityHidden(true)
                            Spacer()
                            Button { rules = true } label: {
                                if typeSize.isAccessibilitySize {
                                    Image(systemName: "questionmark.circle").font(.title2)
                                } else {
                                    Label("How to play", systemImage: "questionmark.circle")
                                }
                            }.accessibilityLabel("How to play")
                                .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                        }
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Race to\nDog Mountain")
                                .font(MountainStyle.display(typeSize.isAccessibilitySize ? 32 : geometry.size.width > 600 ? 76 : 52))
                                .tracking(-2).fixedSize(horizontal: false, vertical: true)
                                .accessibilityAddTraits(.isHeader)
                            if !typeSize.isAccessibilitySize {
                                Text("Pick a number.\nOutsmart your rival.")
                                    .font(.title3.weight(.medium)).lineSpacing(4)
                            }
                        }
                        #if os(macOS)
                        Spacer(minLength: 24)
#else
                        Spacer(minLength: typeSize.isAccessibilitySize ? 40 : 130)
#endif
                        VStack(spacing: 16) {
                            Button { playing = true } label: {
                                HStack { Text("Let's play"); Spacer(); Image(systemName: "arrow.right") }.frame(maxWidth: .infinity)
                            }.buttonStyle(MountainButton(prominent: true)).accessibilityIdentifier("start-game")
                                .keyboardShortcut("n", modifiers: .command)
                            if firstAI || secondAI {
                                HStack(spacing: 12) {
                                    OpponentPortrait(difficulty: difficulty, size: 48)
                                    Text("\(difficulty.name) · \(difficulty.title)").font(.headline)
                                }.accessibilityElement(children: .combine)
                            }
                            Text("Classic · \(size) × \(size) · \(firstAI && secondAI ? "Computer vs. computer" : firstAI || secondAI ? "You move first" : "Two players")")
                                .font(.subheadline).multilineTextAlignment(.center)
                            Button { options = true } label: { Label("Players & board", systemImage: "slider.horizontal.3").frame(maxWidth: .infinity) }
                                .buttonStyle(MountainButton()).accessibilityIdentifier("game-options")
                            if history.contains(where: { $0 > 0 }) {
                                Text("\(names[0])  \(history[0]) : \(history[1])  \(names[1])")
                                    .font(.footnote).multilineTextAlignment(.center)
                                    .accessibilityLabel("Head to head. \(names[0]), \(history[0]) wins. \(names[1]), \(history[1]) wins.")
                            }
                        }
                    }
                    .padding(.horizontal, geometry.size.width > 600 ? 48 : 28).padding(.vertical, 20)
                    .frame(maxWidth: 760, minHeight: geometry.size.height, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }.scrollIndicators(.hidden)
            }
        }
        .foregroundStyle(MountainStyle.cream).tint(MountainStyle.gold).preferredColorScheme(.dark)
    }

#if os(visionOS)
    private var visionHome: some View {
        GeometryReader { geometry in
            ZStack {
                MountainScenery(active: !options && !rules)
                MountainStyle.ink.opacity(0.50).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 32) {
                        HStack {
                            Image(systemName: "pawprint.fill").font(.title).accessibilityHidden(true)
                            Spacer()
                            Button { rules = true } label: { Label("How to play", systemImage: "questionmark.circle") }
                                .buttonStyle(MountainButton()).accessibilityLabel("How to play")
                        }.foregroundStyle(MountainStyle.gold)
                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .center, spacing: 64) {
                                visionInvitation.frame(width: 460)
                                visionLaunch.frame(width: 340)
                            }
                            VStack(alignment: .leading, spacing: 32) { visionInvitation; visionLaunch }
                        }
                    }.padding(48)
                        .frame(maxWidth: 1140, minHeight: geometry.size.height)
                        .frame(maxWidth: .infinity)
                }
            }
        }.foregroundStyle(MountainStyle.cream).tint(MountainStyle.gold).preferredColorScheme(.dark)
    }
    private var visionInvitation: some View {
        VStack(alignment: .leading, spacing: 28) {
            Text("Race to\nDog Mountain").font(MountainStyle.display(64))
                .tracking(-2).fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
            Text("Pick a number.\nOutsmart your rival.").font(.title2).lineSpacing(8)
        }
    }
    private var visionLaunch: some View {
        VStack(spacing: 24) {
            if firstAI || secondAI {
                OpponentPortrait(difficulty: difficulty, size: 132)
                VStack(spacing: 8) {
                    Text(difficulty.name).font(MountainStyle.display(36))
                    Text("\(difficulty.title) · \(difficulty.detail)").font(.headline).multilineTextAlignment(.center)
                }
            }
            Button { playing = true } label: { Label("Let's play", systemImage: "arrow.right").frame(maxWidth: .infinity) }
                .buttonStyle(MountainButton(prominent: true)).accessibilityIdentifier("start-game")
                .keyboardShortcut("n", modifiers: .command)
            Text("Classic · \(size) × \(size) · \(firstAI && secondAI ? "Computer vs. computer" : firstAI || secondAI ? "You move first" : "Two players")")
                .font(.subheadline).multilineTextAlignment(.center)
            Button { options = true } label: { Label("Players & board", systemImage: "slider.horizontal.3").frame(maxWidth: .infinity) }
                .buttonStyle(MountainButton()).accessibilityIdentifier("game-options")
            if history.contains(where: { $0 > 0 }) {
                Text("\(names[0])  \(history[0]) : \(history[1])  \(names[1])").font(.footnote).multilineTextAlignment(.center)
            }
        }.offset(z: 20)
    }
#endif

    private var difficulty: ComputerDifficulty { ComputerDifficulty(rawValue: computerLevel) ?? .level6 }
    private var names: [String] { [clean(firstName, fallback: "Player 1"), clean(secondName, fallback: "Player 2")] }
    private func clean(_ name: String, fallback: String) -> String {
        let result = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? fallback : result
    }
    private func refreshHistory() {
        history = [0, 1].map { UserDefaults.standard.integer(forKey: "\(names[$0])vvv\(names[1 - $0])") }
    }
    private var playerOptions: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Text("Who's climbing?").font(MountainStyle.display(32))
                    playerEditor(name: $firstName, computer: $firstAI, index: 0)
                    playerEditor(name: $secondName, computer: $secondAI, index: 1)
                    if firstAI || secondAI {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 16) {
                                OpponentPortrait(difficulty: difficulty, size: 80)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(difficulty.name).font(MountainStyle.display(28))
                                    Text(difficulty.detail).font(.subheadline)
                                }
                            }
                            Stepper(value: $computerLevel, in: 0...15) {
                                Text("Difficulty · \(difficulty.title) of 16").font(.headline).monospacedDigit()
                            }.accessibilityIdentifier("computer-difficulty")
                            Picker("Choose an opponent", selection: $computerLevel) {
                                ForEach(ComputerDifficulty.allCases) { profile in
                                    Text("\(profile.title) · \(profile.name)").tag(profile.rawValue)
                                }
                            }.pickerStyle(.menu)
                            Text("A little tougher after you win, a little gentler after you lose. Your selected level stays the same.").font(.footnote)
                            Toggle("Opponent chat", isOn: $computerDialogue)
                                .accessibilityIdentifier("opponent-chat")
                            Text("Optional phrases from your rival. Off by default.").font(.footnote)
                        }
                        Divider().overlay(MountainStyle.cream.opacity(0.2))
                    }
                    Stepper(value: $size, in: 4...14) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Board size").font(.headline)
                            Text("\(size) × \(size)").font(.title2.bold()).monospacedDigit().foregroundStyle(MountainStyle.gold)
                        }
                    }
                    Text("Bigger board, more possibilities. Classic rules, every time.").font(.subheadline)
                    HStack {
                        Text("Head to head").font(.headline)
                        Spacer()
                        Text("\(history[0]) : \(history[1])").monospacedDigit().foregroundStyle(MountainStyle.gold)
                    }
                    Link("Privacy Policy", destination: URL(string: "https://nathanfennel.com/race-to-dog-mountain/privacy.html")!).font(.footnote).frame(minHeight: 44)
                }.padding(28).frame(maxWidth: 620).frame(maxWidth: .infinity)
            }
            .background(MountainStyle.ink).navigationTitle("Players & board").mountainInlineTitle()
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { options = false } } }
        }.tint(MountainStyle.gold).foregroundStyle(MountainStyle.cream).preferredColorScheme(.dark)
            .onChange(of: computerLevel) { computerAdjustment = 0 }
    }
    private func playerEditor(name: Binding<String>, computer: Binding<Bool>, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(index == 0 ? "Row player" : "Column player", systemImage: index == 0 ? "arrow.left.and.right" : "arrow.up.and.down")
                .font(.headline).foregroundStyle(MountainStyle.player(index))
            TextField(index == 0 ? "First player" : "Second player", text: name)
                .font(.title3.weight(.semibold)).padding(16)
                .background(MountainStyle.cream.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityLabel(index == 0 ? "First player name" : "Second player name")
            Toggle("Computer player", isOn: computer).tint(MountainStyle.player(index))
        }
    }
}

private struct MountainRules: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Text("Small moves.\nBig decisions.").font(MountainStyle.display(36))
                    instruction("arrow.left.and.right", "Pick from your row", "The gold player chooses a number from the highlighted row. That number is added to their score.", MountainStyle.gold)
                    instruction("arrow.up.and.down", "Send your rival down a column", "Your tile sets the mint player's column. Their choice then sets your next row.", MountainStyle.mint)
                    instruction("flag.checkered", "Finish on top", "Used tiles stay empty. When the next player has no moves, the higher score wins. You move first against the computer. Computer-only games wait until you tap Play.", MountainStyle.cream)
                    Text("The biggest number isn't always the best move. Think about what you leave behind.").font(.title3.weight(.medium))
                    Button("Got it") { dismiss() }.buttonStyle(MountainButton(prominent: true))
                }.padding(28).frame(maxWidth: 620).frame(maxWidth: .infinity)
            }.background(MountainStyle.ink).navigationTitle("How to play").mountainInlineTitle()
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }.foregroundStyle(MountainStyle.cream).tint(MountainStyle.gold).preferredColorScheme(.dark)
    }
    private func instruction(_ symbol: String, _ title: String, _ text: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol).font(.headline).foregroundStyle(color)
            Text(text).font(.body).lineSpacing(4)
        }
    }
}

private struct MountainGameView: View {
    let names: [String]
    let difficulty: ComputerDifficulty
    let onLeave: (() -> Void)?
    @AppStorage("computerAdjustment") private var computerAdjustment = 0
    @AppStorage("computerDialogue") private var computerDialogue = false
    @State private var matchAdjustment: Int
    @State private var rolesChanged = false
    @State private var computerStarted = false
    @State private var replaying = false
    @State private var lastComputerMove: MountainReplay?
    @State private var computers: [Bool]
    @State private var game: MountainGame
    @State private var recorded = false
    @State private var confirmExit = false
    @State private var foregroundNonce = 0
    @State private var lastMove: Int?
    @State private var lastPoints = 0
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize

    init(size: Int, names: [String], computers: [Bool], difficulty: ComputerDifficulty, adjustment: Int, onLeave: (() -> Void)? = nil) {
        self.names = names
        self.onLeave = onLeave
        self.difficulty = difficulty
        _matchAdjustment = State(initialValue: adjustment)
        // Each presentation owns a fresh game and a snapshot of player settings.
        _game = State(initialValue: MountainGame(size: size, firstPlayer: MountainGame.startingPlayer(computers: computers)))
        _computers = State(initialValue: computers)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                MountainScenery(active: !replaying && !confirmExit, celebration: game.isOver)
                MountainStyle.ink.opacity(0.60).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 24) {
                        header
#if os(visionOS)
                        if geometry.size.width >= 1040 && !typeSize.isAccessibilitySize {
                            turnLabel
                            HStack(alignment: .center, spacing: 24) {
                                score(player: 0).frame(width: 180).offset(z: 24)
                                board(width: min(geometry.size.width - 472, 740)).offset(z: 12)
                                score(player: 1).frame(width: 180).offset(z: 24)
                            }
                            startComputerButton
                            matchControls.frame(maxWidth: 520)
                        } else {
                            verticalGame(width: min(geometry.size.width - 64, 740))
                        }
#elseif os(macOS)
                        if geometry.size.width >= 900 {
                            HStack(alignment: .top, spacing: 24) {
                                VStack(spacing: 18) {
                                    score(player: 0)
                                    score(player: 1)
                                    turnLabel
                                    startComputerButton
                                    matchControls
                                }.frame(width: 260)
                                board(width: min(geometry.size.width - 316, 760))
                            }
                        } else {
                            verticalGame(width: min(geometry.size.width - 32, 760))
                        }
#else
                        verticalGame(width: min(geometry.size.width - 32, 760))
#endif
                    }
#if os(visionOS)
                    .padding(32).frame(maxWidth: 1268)
#else
                    .padding(16)
#endif
#if os(macOS)
                        .frame(maxWidth: 1076)
#elseif os(iOS)
                        .frame(maxWidth: 792)
#endif
                        .frame(maxWidth: .infinity)
                }.scrollIndicators(.hidden)
            }
            .confirmationDialog("Leave this game?", isPresented: $confirmExit, titleVisibility: .visible) {
                Button("Leave game", role: .destructive) { leaveGame() }
            } message: { Text("This unfinished game will not count toward your wins.") }
            .onReceive(NotificationCenter.default.publisher(for: MountainPlatform.didBecomeActive)) { _ in foregroundNonce += 1 }
            .task(id: "\(game.moves)-\(computers)-\(confirmExit)-\(foregroundNonce)-\(computerStarted)-\(replaying)") {
                guard MountainPlatform.isActive, !confirmExit, !replaying, !waitingForStart, !game.isOver, computers[game.turn] else { return }
                do { try await Task.sleep(for: .milliseconds(700)) } catch { return }
                let snapshot = game, profile = difficulty, skill = matchAdjustment
                let next = await Task.detached(priority: .userInitiated) {
                    snapshot.computerMove(difficulty: profile, adjustment: skill)
                }.value
                guard !Task.isCancelled, !confirmExit, !replaying, MountainPlatform.isActive else { return }
                if let next { move(next, computer: true) }
            }
            .onChange(of: game.isOver) { _, over in if over { recordWin() } }
            .onChange(of: computers) { rolesChanged = true }
            .sheet(isPresented: $replaying) {
                if let replay = lastComputerMove { MountainReplayView(replay: replay).mountainSheetSize() }
            }
        }
        .foregroundStyle(MountainStyle.cream).tint(MountainStyle.gold).preferredColorScheme(.dark)
        .mountainGameFeedback(moves: game.moves, over: game.isOver)
#if os(macOS)
        .focusedSceneValue(\.mountainActions, MountainActions(newGame: { restart() }, replay: lastComputerMove == nil ? nil : { replaying = true }, close: { if game.isOver { leaveGame() } else { confirmExit = true } }))
#endif
    }
    private func board(width: CGFloat) -> some View {
        MountainBoard(game: game, availableWidth: width, interactive: !computers[game.turn], lastMove: lastMove, lastPoints: lastPoints) { move($0) }
    }
    private func verticalGame(width: CGFloat) -> some View {
        VStack(spacing: 24) {
            if typeSize.isAccessibilitySize {
                VStack(spacing: 14) { score(player: 0); score(player: 1) }
            } else {
                HStack(spacing: 14) { score(player: 0); score(player: 1) }
            }
            turnLabel
            startComputerButton
            board(width: width)
            matchControls
        }
    }
    @ViewBuilder private var startComputerButton: some View {
        if waitingForStart {
            Button { computerStarted = true } label: {
                Label("Play · Start computer", systemImage: "play.fill").frame(maxWidth: .infinity)
            }.buttonStyle(MountainButton(prominent: true)).accessibilityIdentifier("start-computer")
        }
    }
    private var matchControls: some View {
        VStack(spacing: 24) {
            Button { replaying = true } label: {
                Label("Replay computer move", systemImage: "play.rectangle").frame(maxWidth: .infinity)
            }.buttonStyle(MountainButton()).disabled(lastComputerMove == nil)
                .opacity(lastComputerMove == nil ? 0.5 : 1)
                .accessibilityIdentifier("replay-computer")
                .keyboardShortcut("r", modifiers: .command)
            if lastComputerMove == nil {
                Text("Replay will be ready after the computer's first move.").font(.footnote).multilineTextAlignment(.center)
            }
            if game.isOver {
                VStack(spacing: 12) {
                    Button { restart() } label: { Label("Race again", systemImage: "arrow.clockwise").frame(maxWidth: .infinity) }
                        .buttonStyle(MountainButton(prominent: true))
                    Button("Back to mountain") { leaveGame() }.buttonStyle(MountainButton())
                }.transition(.opacity)
            } else {
                Label("Every choice sets your rival's next move.", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                    .font(.footnote).multilineTextAlignment(.center)
            }
        }
    }
    private func leaveGame() { if let onLeave { onLeave() } else { dismiss() } }
    private var waitingForStart: Bool { game.moves == 0 && computers[game.turn] && !computerStarted }
    private func playerName(_ index: Int) -> String { computers[index] ? difficulty.name : names[index] }
    private var header: some View {
        HStack {
            Button { if game.isOver { leaveGame() } else { confirmExit = true } } label: {
                Image(systemName: "xmark").frame(width: MountainStyle.headerControlSize, height: MountainStyle.headerControlSize)
                    .background(MountainStyle.cream.opacity(0.1), in: Circle())
            }.accessibilityLabel("Close game").accessibilityIdentifier("close-game")
                .keyboardShortcut(.cancelAction)
                .mountainHover()
            Spacer()
            Label("Dog Mountain", systemImage: "pawprint.fill").font(.headline)
            Spacer()
            Menu {
                Toggle("Computer: \(names[0])", isOn: $computers[0])
                Toggle("Computer: \(names[1])", isOn: $computers[1])
                Toggle("Opponent chat", isOn: $computerDialogue)
            } label: {
                Image(systemName: "person.2.fill").frame(width: MountainStyle.headerControlSize, height: MountainStyle.headerControlSize)
                    .background(MountainStyle.cream.opacity(0.1), in: Circle())
            }.accessibilityLabel("Player controls").mountainHover()
        }.buttonStyle(.plain)
    }
    private var turnLabel: some View {
        VStack(spacing: 8) {
            if game.isOver {
                Image(systemName: "flag.checkered").font(.largeTitle).foregroundStyle(MountainStyle.gold).accessibilityHidden(true)
                Text(result).font(MountainStyle.display(30)).multilineTextAlignment(.center)
                Text(game.scores[0] == game.scores[1] ? "An even climb. Go again?" : "The mountain has a winner.").font(.subheadline)
                if computerDialogue, computers.filter({ $0 }).count == 1, game.scores[0] != game.scores[1] {
                    Text("“\(difficulty.resultPhrase(humanWon: !computers[game.scores[0] > game.scores[1] ? 0 : 1]))”").font(.subheadline.italic()).multilineTextAlignment(.center)
                }
            } else {
                Label("\(playerName(game.turn))'s \(game.turn == 0 ? "row" : "column")", systemImage: game.turn == 0 ? "arrow.left.and.right" : "arrow.up.and.down")
                    .font(.title2.bold()).foregroundStyle(MountainStyle.player(game.turn)).multilineTextAlignment(.center)
                    .contentTransition(.opacity)
                Text(waitingForStart ? "Select Play when you’re ready." : computers[game.turn] ? "\(difficulty.name) is choosing…" : "Choose a \(game.turn == 0 ? "gold" : "mint") tile. Take its points.")
                    .font(.subheadline).multilineTextAlignment(.center)
                if computerDialogue, computers.contains(true) {
                    Text("“\(lastComputerMove == nil ? difficulty.greeting : difficulty.phrase(move: lastComputerMove!.after.moves))”")
                        .font(.subheadline.italic()).multilineTextAlignment(.center)
                }
            }
        }.frame(maxWidth: .infinity).accessibilityElement(children: .combine)
    }
    private var result: String {
        game.scores[0] == game.scores[1] ? "A tie!" : "\(playerName(game.scores[0] > game.scores[1] ? 0 : 1)) wins!"
    }
    private func score(player: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if computers[player] {
                HStack(spacing: 10) {
                    OpponentPortrait(difficulty: difficulty, size: 48, thinking: game.turn == player && !game.isOver && !waitingForStart && !replaying && !confirmExit, reaction: lastComputerMove?.after.moves ?? 0)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(difficulty.name).font(.subheadline.weight(.semibold))
                        Text(difficulty.title).font(.caption)
                    }
                }
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "person.fill").frame(width: 48, height: 48)
                        .background(MountainStyle.player(player).opacity(0.12), in: Circle()).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(names[player]).font(.subheadline.weight(.semibold)).lineLimit(2)
                        Text(player == 0 ? "Row player" : "Column player").font(.caption)
                    }
                }
            }
            Text("\(game.scores[player])").font(MountainStyle.display(40)).monospacedDigit()
                .contentTransition(reduceMotion ? .identity : .numericText())
            HStack(spacing: 6) {
                Image(systemName: player == 0 ? "arrow.left.and.right" : "arrow.up.and.down")
                Text(game.turn == player && !game.isOver ? computers[player] ? waitingForStart ? "Ready" : "Thinking" : "Your turn" : "Points")
            }.font(.caption.weight(.semibold))
        }.frame(maxWidth: .infinity, alignment: .leading).padding(18)
            .foregroundStyle(MountainStyle.player(player))
            .background(MountainStyle.player(player).opacity(game.turn == player && !game.isOver ? 0.17 : 0.06), in: RoundedRectangle(cornerRadius: 16))
            .overlay(alignment: .bottom) {
                Capsule().fill(game.turn == player && !game.isOver ? MountainStyle.player(player) : .clear).frame(height: 3).padding(.horizontal, 18)
            }
            .accessibilityElement(children: .combine)
    }
    private func move(_ id: Int, computer: Bool = false) {
        guard game.canPlay(id) else { return }
        if computer { lastComputerMove = MountainReplay(before: game, tileID: id, difficulty: difficulty) }
        lastPoints = game.tiles[id].value
        withAnimation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.8)) {
            lastMove = id
            _ = game.play(id)
        }
    }
    private func restart() {
        game = MountainGame(size: game.size, firstPlayer: MountainGame.startingPlayer(computers: computers))
        recorded = false; lastMove = nil; lastPoints = 0; lastComputerMove = nil
        computerStarted = false; rolesChanged = false; matchAdjustment = computerAdjustment
        foregroundNonce += 1
    }
    private func recordWin() {
        guard !recorded else { return }
        recorded = true
        guard game.scores[0] != game.scores[1] else { return }
        let winner = game.scores[0] > game.scores[1] ? 0 : 1
        if !rolesChanged, computers.filter({ $0 }).count == 1 {
            computerAdjustment = ComputerDifficulty.adjusted(matchAdjustment, humanWon: !computers[winner])
        }
        let key = "\(names[winner])vvv\(names[1 - winner])"
        UserDefaults.standard.set(UserDefaults.standard.integer(forKey: key) + 1, forKey: key)
    }
}

private struct MountainBoard: View {
    let game: MountainGame
    let availableWidth: CGFloat
    var interactive = false
    var lastMove: Int?
    var lastPoints = 0
    var selected: Int?
    var select: (Int) -> Void = { _ in }
    #if os(visionOS)
    @ScaledMetric(relativeTo: .title3) private var minimumTile: CGFloat = 60
    private let gap: CGFloat = 12
    private let maximumTile: CGFloat = 92
#else
    @ScaledMetric(relativeTo: .title3) private var minimumTile: CGFloat = 44
    private let gap: CGFloat = 6
    private let maximumTile: CGFloat = 76
#endif
    var body: some View {
        let width = max(minimumTile, min(maximumTile, (availableWidth - 24 - CGFloat(game.size - 1) * gap) / CGFloat(game.size)))
        return ScrollView(.horizontal) {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(width), spacing: gap), count: game.size), spacing: gap) {
                ForEach(game.tiles) { tile in
                    let playable = game.canPlay(tile.id)
                    Button { select(tile.id) } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(tile.value == 0 ? MountainStyle.cream.opacity(0.035) : playable ? MountainStyle.player(game.turn) : MountainStyle.cream)
                            if tile.value == 0 {
                                if lastMove == tile.id {
                                    Text("+\(lastPoints)").font(.caption.bold()).foregroundStyle(MountainStyle.cream)
                                } else {
                                    Image(systemName: "pawprint.fill").font(.caption).foregroundStyle(MountainStyle.cream.opacity(0.22))
                                }
                            } else {
                                Text("\(tile.value)").font(.title3.weight(.heavy)).monospacedDigit().foregroundStyle(MountainStyle.ink)
                            }
                        }.frame(width: width, height: width)
                            .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(playable ? MountainStyle.cream.opacity(0.75) : .clear, lineWidth: 2)
                                if selected == tile.id { RoundedRectangle(cornerRadius: 12).strokeBorder(MountainStyle.gold, lineWidth: 5) }
                            }
                            .shadow(color: .black.opacity(tile.value == 0 ? 0 : 0.2), radius: 3, x: 0, y: 3)
                    }
                    .buttonStyle(MountainTileButton()).mountainHover().disabled(!playable || !interactive || game.isOver)
                    .accessibilityLabel("Row \(tile.id / game.size + 1), column \(tile.id % game.size + 1), \(tile.value == 0 ? "used" : String(tile.value))")
                    .accessibilityHint(playable ? "Adds \(tile.value) points and sets the next player's \(game.turn == 0 ? "column" : "row")" : "")
                    .accessibilityIdentifier("tile-\(tile.id)")
                }
            }.padding(12).frame(minWidth: availableWidth)
        }
        .background(MountainStyle.ink.opacity(0.7), in: RoundedRectangle(cornerRadius: 20))
        .scrollIndicators(.visible)
    }
}

private struct OpponentPortrait: View {
    let difficulty: ComputerDifficulty
    var size: CGFloat = 64
    var thinking = false
    var reaction = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Image(difficulty.portrait).resizable().scaledToFill()
            .frame(width: size, height: size).clipShape(Circle())
            .overlay { Circle().strokeBorder(MountainStyle.gold.opacity(0.65), lineWidth: 2) }
            .phaseAnimator([false, true], trigger: reaction) { content, phase in
                content.scaleEffect(!reduceMotion && phase ? 1.06 + Double(difficulty.rawValue % 4) * 0.01 : 1)
                    .rotationEffect(.degrees(!reduceMotion && phase ? Double(difficulty.rawValue % 2 == 0 ? 4 : -4) : 0))
            } animation: { _ in reduceMotion ? nil : .spring(response: 0.3 + Double(difficulty.rawValue) * 0.015) }
            .phaseAnimator(thinking && !reduceMotion && scenePhase == .active ? [false, true] : [false]) { content, phase in
                content.offset(y: phase ? -2 - CGFloat(difficulty.rawValue % 3) : 0)
            } animation: { _ in .easeInOut(duration: 0.7 + Double(difficulty.rawValue) * 0.04) }
            .accessibilityHidden(true)
    }
}

private struct MountainReplayView: View {
    let replay: MountainReplay
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var stage = 0
    @State private var playback = 0
    private var shown: MountainGame { stage == 2 ? replay.after : replay.before }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 24) {
                        HStack(spacing: 14) {
                            OpponentPortrait(difficulty: replay.difficulty, size: 64, reaction: stage)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(replay.difficulty.name)'s move").font(MountainStyle.display(28))
                                Text(replay.difficulty.title).font(.subheadline)
                            }
                        }
                        Text(stage == 0 ? "Before the move" : stage == 1 ? "Choosing \(replay.before.tiles[replay.tileID].value) points" : "\(replay.difficulty.name) takes \(replay.before.tiles[replay.tileID].value) points")
                            .font(.title3.bold()).multilineTextAlignment(.center)
                        Text("Row player \(shown.scores[0]) · Column player \(shown.scores[1])").monospacedDigit()
                        MountainBoard(game: shown, availableWidth: min(geometry.size.width - 32, 760), lastMove: stage == 2 ? replay.tileID : nil, lastPoints: replay.before.tiles[replay.tileID].value, selected: stage > 0 ? replay.tileID : nil)
                        Text("Row \(replay.tileID / shown.size + 1), column \(replay.tileID % shown.size + 1). Sets the next \(replay.before.turn == 0 ? "column" : "row").")
                            .font(.subheadline).multilineTextAlignment(.center)
                        Button { stage = 0; playback += 1 } label: { Label("Play again", systemImage: "play.fill").frame(maxWidth: .infinity) }
                            .buttonStyle(MountainButton(prominent: true)).accessibilityIdentifier("replay-again")
                        Text("Your live game is paused. Replay never changes its score.").font(.footnote).multilineTextAlignment(.center)
                    }.padding(16).frame(maxWidth: 792).frame(maxWidth: .infinity)
                }.scrollIndicators(.hidden)
            }.background(MountainStyle.ink)
                .navigationTitle("Computer replay").mountainInlineTitle()
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .task(id: playback) {
                    if reduceMotion { stage = 2; return }
                    do {
                        try await Task.sleep(for: .milliseconds(700))
                        withAnimation(.easeOut(duration: 0.25)) { stage = 1 }
                        try await Task.sleep(for: .milliseconds(900))
                        withAnimation(.spring(response: 0.4)) { stage = 2 }
                    } catch { return }
                }
        }.foregroundStyle(MountainStyle.cream).tint(MountainStyle.gold).preferredColorScheme(.dark)
    }
}

private extension View {
    @ViewBuilder func mountainHover() -> some View {
#if os(visionOS)
        contentShape(.hoverEffect, RoundedRectangle(cornerRadius: 16)).hoverEffect(.highlight)
#else
        self
#endif
    }
    @ViewBuilder func mountainInlineTitle() -> some View {
#if os(iOS)
        navigationBarTitleDisplayMode(.inline)
#else
        self
#endif
    }
    @ViewBuilder func mountainSheetSize() -> some View {
#if os(macOS) || os(visionOS)
        frame(minWidth: 600, idealWidth: 650, minHeight: 680, idealHeight: 820)
#else
        self
#endif
    }
    @ViewBuilder func mountainGameFeedback(moves: Int, over: Bool) -> some View {
#if os(iOS)
        sensoryFeedback(.selection, trigger: moves)
            .sensoryFeedback(.success, trigger: over) { _, finished in finished }
#else
        self
#endif
    }
}
