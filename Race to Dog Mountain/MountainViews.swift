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
    @State private var selection: SavedMountainGame?
    @State private var library = MountainLibrary()
    @State private var friends = MountainFriends()
    @Environment(\.scenePhase) private var phase
    @State private var options = false
    @State private var rules = false
#if os(iOS)
    @State private var messageHelp = false
#endif
    @State private var history = [0, 0]
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Group {
#if os(macOS) || os(visionOS)
            if playing {
                localGame
            } else {
#if os(macOS)
                home.focusedSceneValue(\.mountainActions, MountainActions(newGame: { startLocal() }, options: { options = true }, rules: { rules = true }))
#else
                visionHome
#endif
            }
#else
            home.fullScreenCover(isPresented: $playing, onDismiss: refreshHistory) {
                localGame
            }
#endif
        }
        .sheet(isPresented: $options, onDismiss: refreshHistory) { playerOptions.mountainSheetSize() }
        .sheet(isPresented: $rules) { MountainRules().mountainSheetSize() }
#if os(iOS)
        .sheet(isPresented: $messageHelp) { MountainMessagesHelp() }
#endif
        .onAppear { size = min(max(size, 4), 14); refreshHistory() }
        .task { await friends.resume() }
        .onChange(of: phase) { _, phase in if phase == .active { Task { await friends.refresh() } } }
        .sheet(item: $friends.presentation, onDismiss: friends.presentationDismissed) { MountainGameCenterPresenter(controller: $0.controller).mountainSheetSize() }
        .sheet(item: $friends.opened) { _ in MountainFriendGame(friends: friends).mountainSheetSize() }
        .alert("Friend games", isPresented: Binding(get: { friends.error != nil && friends.opened == nil }, set: { if !$0 { friends.error = nil } })) {
            Button("OK") { friends.error = nil }
        } message: { Text(friends.error ?? "") }
        .onChange(of: firstName) { refreshHistory() }
        .onChange(of: secondName) { refreshHistory() }
    }

    private var home: some View {
        GeometryReader { geometry in
            ZStack {
                MountainScenery(active: !playing && !options && !rules).overlay(MountainStyle.ink.opacity(0.5))
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
                                .font(MountainStyle.display(typeSize.isAccessibilitySize ? 32 : !library.active.isEmpty || !friends.active.isEmpty ? 36 : geometry.size.width > 600 ? 76 : 52))
                                .tracking(typeSize.isAccessibilitySize || !library.active.isEmpty || !friends.active.isEmpty ? -1 : -2).fixedSize(horizontal: false, vertical: true)
                                .accessibilityAddTraits(.isHeader)
                            if !typeSize.isAccessibilitySize {
                                Text("Pick a number.\nOutsmart your rival.")
                                    .font(.title3.weight(.medium)).lineSpacing(4)
                            }
                        }
                        if library.active.isEmpty && friends.active.isEmpty { Spacer(minLength: 24) }
                        VStack(spacing: 16) {
                            Button { startLocal() } label: {
                                HStack { Text("New local game"); Spacer(); Image(systemName: "arrow.right") }.frame(maxWidth: .infinity)
                            }.buttonStyle(MountainButton(prominent: true)).accessibilityIdentifier("start-game")
                                .keyboardShortcut("n", modifiers: .command)
                            socialActions
                            gamesInbox
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
                        socialActions.frame(maxWidth: 650)
                        gamesInbox.frame(maxWidth: 900)
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
            Button { startLocal() } label: { Label("Let's play", systemImage: "arrow.right").frame(maxWidth: .infinity) }
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

    private var localGame: some View {
        MountainGameView(size: size, names: names, computers: [firstAI, secondAI], difficulty: difficulty,
                         adjustment: computerAdjustment, saved: selection, onSave: library.save,
                         onLeave: { playing = false; refreshHistory() })
    }
    private func startLocal(passAndPlay: Bool = false) {
        let next = SavedMountainGame(size: size, names: names, computers: passAndPlay ? [false, false] : [firstAI, secondAI], difficulty: difficulty, adjustment: computerAdjustment)
        library.save(next); selection = next; playing = true
    }
    private func resume(_ game: SavedMountainGame) { selection = game; playing = true }
    private var socialActions: some View {
        VStack(spacing: 12) {
            Button { friends.invite(size: size) } label: { Label("Play a friend", systemImage: "person.2.fill").frame(maxWidth: .infinity) }
                .buttonStyle(MountainButton()).disabled(friends.sending).accessibilityIdentifier("play-friend")
            HStack(spacing: 16) {
                Button { startLocal(passAndPlay: true) } label: {
                    Label("Pass & play", systemImage: "iphone.gen3.radiowaves.left.and.right")
#if os(visionOS)
                        .foregroundStyle(MountainStyle.ink)
#endif
                }
                    .frame(minHeight: 44).accessibilityIdentifier("pass-and-play")
#if os(iOS)
                Button { messageHelp = true } label: { Label("iMessage", systemImage: "message.fill") }.frame(minHeight: 44)
#endif
            }.font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity)
            if friends.authenticated {
                HStack {
                    Text("Game Center connected").font(.caption)
                    Spacer()
                    Button { Task { await friends.refresh() } } label: { Image(systemName: "arrow.clockwise") }.frame(minWidth: 44, minHeight: 44).disabled(friends.loading).accessibilityLabel("Refresh friend games")
                }
            }
            if friends.loading { ProgressView("Refreshing friend games…").tint(MountainStyle.gold) }
        }
    }
    private var gamesInbox: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !friends.active.isEmpty || !library.active.isEmpty {
                Text("Your games").font(.title2.bold()).accessibilityAddTraits(.isHeader)
                ForEach(friends.active) { race in
                    MountainMatchRow(title: race.title, subtitle: race.yourTurn ? "Your move · Game Center" : "Waiting for a friend · Game Center", scores: race.challenge?.game.scores, symbol: "person.2.fill", needsMove: race.yourTurn) { Task { await friends.open(race.id) } }
                }
                ForEach(library.active) { saved in
                    MountainMatchRow(title: saved.title, subtitle: "\(saved.computers.contains(true) ? saved.difficulty.title : "Pass & play") · \(saved.game.size) × \(saved.game.size)", scores: saved.game.scores, symbol: saved.computers.contains(true) ? "person.crop.square" : "person.2.fill", needsMove: true) { resume(saved) }
                }
            } else {
                Text("Start a race with a friend. Come back here whenever it's your move.").fixedSize(horizontal: false, vertical: true)
                    .font(.subheadline).multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.vertical, 8)
            }
            if !library.finished.isEmpty || !friends.finished.isEmpty {
                DisclosureGroup("Finished games") {
                    ForEach(friends.finished) { race in
                        MountainMatchRow(title: race.title, subtitle: "Finished · Game Center", scores: race.challenge?.game.scores, symbol: "flag.checkered") { Task { await friends.open(race.id) } }
                    }
                    ForEach(library.finished) { saved in
                        MountainMatchRow(title: saved.title, subtitle: "Finished · Local", scores: saved.game.scores, symbol: "flag.checkered") { resume(saved) }
                    }
                }.padding(.top, 12)
            }
            if let error = library.error { Text(error).font(.footnote).foregroundStyle(MountainStyle.gold) }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var difficulty: ComputerDifficulty { ComputerDifficulty(rawValue: computerLevel) ?? .level6 }
    private var names: [String] { [clean(firstName, fallback: "Player 1"), clean(secondName, fallback: "Player 2")] }
    private func clean(_ name: String, fallback: String) -> String {
        let result = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? fallback : String(result.prefix(60))
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
    let onSave: ((SavedMountainGame) -> Void)?
    @State private var savedID: UUID
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

    init(size: Int, names: [String], computers: [Bool], difficulty: ComputerDifficulty, adjustment: Int, saved: SavedMountainGame? = nil, onSave: ((SavedMountainGame) -> Void)? = nil, onLeave: (() -> Void)? = nil) {
        self.names = saved?.names ?? names
        self.onLeave = onLeave; self.onSave = onSave
        self.difficulty = saved?.difficulty ?? difficulty
        _savedID = State(initialValue: saved?.id ?? UUID())
        _recorded = State(initialValue: saved?.recorded ?? false)
        _computerStarted = State(initialValue: saved?.computerStarted ?? false)
        _rolesChanged = State(initialValue: saved?.rolesChanged ?? false)
        _lastComputerMove = State(initialValue: saved?.replay)
        _matchAdjustment = State(initialValue: saved?.adjustment ?? adjustment)
        // Each presentation owns a fresh game and a snapshot of player settings.
        _game = State(initialValue: saved?.game ?? MountainGame(size: size, firstPlayer: MountainGame.startingPlayer(computers: computers)))
        _computers = State(initialValue: saved?.computers ?? computers)
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
                Button("Back to games") { leaveGame() }
            } message: { Text("Your progress is saved. You can finish this game later.") }
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
            .onChange(of: computers) { rolesChanged = true; persist() }
            .onChange(of: computerStarted) { persist() }
            .onDisappear { persist() }
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
    private func leaveGame() { persist(); if let onLeave { onLeave() } else { dismiss() } }
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
        if game.isOver { recordWin() }
        persist()
    }
    private func persist() {
        var saved = SavedMountainGame(size: game.size, names: names, computers: computers, difficulty: difficulty, adjustment: matchAdjustment)
        saved.id = savedID; saved.game = game; saved.replay = lastComputerMove
        saved.recorded = recorded; saved.computerStarted = computerStarted; saved.rolesChanged = rolesChanged
        onSave?(saved)
    }
    private func restart() {
        savedID = UUID()
        game = MountainGame(size: game.size, firstPlayer: MountainGame.startingPlayer(computers: computers))
        recorded = false; lastMove = nil; lastPoints = 0; lastComputerMove = nil
        computerStarted = false; rolesChanged = false; matchAdjustment = computerAdjustment
        foregroundNonce += 1; persist()
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
