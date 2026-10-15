import SwiftUI
import Observation
import ImageIO
import UniformTypeIdentifiers
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

@MainActor @Observable private final class MountainPrimaryActivity { var phase: ScenePhase = .inactive }

private struct MountainPrimaryRoot: View {
    let activity: MountainPrimaryActivity
    var body: some View { MountainHome().offeringMountainDisplay().environment(\.scenePhase, activity.phase) }
}

@objc(DMModernSceneDelegate)
final class MountainSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private let activity = MountainPrimaryActivity()
    private static weak var primary: MountainSceneDelegate?
    private final class WeakScene { weak var value: MountainSceneDelegate?; init(_ value: MountainSceneDelegate) { self.value = value } }
    private static var scenes: [String: WeakScene] = [:]
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: scene)
        self.window = window
        Self.scenes[session.persistentIdentifier] = WeakScene(self)
        if Self.primary == nil { Self.primary = self }
        configureRoot()
        window.makeKeyAndVisible()
    }
    private func configureRoot() {
        if Self.primary === self {
            window?.rootViewController = UIHostingController(rootView: MountainPrimaryRoot(activity: activity))
        } else {
            // Additional interactive windows are read-only viewers, never second game/AI owners.
            window?.rootViewController = UIHostingController(rootView: MountainExternalScreen())
        }
    }
    func sceneDidBecomeActive(_ scene: UIScene) { activity.phase = .active }
    func sceneWillResignActive(_ scene: UIScene) { activity.phase = .inactive }
    func sceneDidEnterBackground(_ scene: UIScene) { activity.phase = .background }
    func sceneDidDisconnect(_ scene: UIScene) {
        activity.phase = .background
        Self.scenes.removeValue(forKey: scene.session.persistentIdentifier)
        window = nil
        if Self.primary === self {
            Self.primary = Self.scenes.values.compactMap(\.value).first
            Self.primary?.configureRoot()
        }
    }
}

#endif

struct MountainHome: View {
    @AppStorage("boardScrollThreshold", store: MountainExperience.defaults) private var boardScrollThreshold = 7
    @AppStorage("showStatusBar", store: MountainExperience.defaults) private var showStatusBar = false
    @AppStorage("player1Name", store: MountainExperience.defaults) private var firstName = "Player 1"
    @AppStorage("player2Name", store: MountainExperience.defaults) private var secondName = "Player 2"
    @AppStorage("player1AI", store: MountainExperience.defaults) private var firstAI = false
    @AppStorage("player2AI", store: MountainExperience.defaults) private var secondAI = true
    @AppStorage("complexity", store: MountainExperience.defaults) private var size = 6
    @AppStorage("computerLevel", store: MountainExperience.defaults) private var computerLevel = 5
    @AppStorage("adaptiveDifficulty", store: MountainExperience.defaults) private var adaptiveDifficulty = true
    @AppStorage("computerDialogue", store: MountainExperience.defaults) private var computerDialogue = false
    @State private var playing = false
    @State private var selection: SavedMountainGame?
    @State private var library = MountainLibrary()
    @State private var learningStore = MountainLearningStore.shared
    @State private var resetLearning = false
#if os(iOS)
    @State private var friends = MountainPhoneCoordinator.shared.friends
#else
    @State private var friends = MountainFriends()
#endif
    @Environment(\.scenePhase) private var phase
    @State private var options = false
    @State private var rules = false
    @State private var social = false
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
                home
#endif
            }
#else
            home.fullScreenCover(isPresented: $playing, onDismiss: refreshHistory) {
                localGame
            }
#endif
        }
        .defaultAppStorage(MountainExperience.defaults)
#if DEBUG
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(MountainExperience.qaSession == nil ? "mountain.root" : "mountain.private.session")
        .accessibilityValue(MountainExperience.qaSession?.uuidString ?? "normal")
#endif
        .overlay(alignment: .topTrailing) {
#if DEBUG
            if MountainExperience.qaSession != nil,
               !ProcessInfo.processInfo.arguments.contains("-MountainMarketingCapture") {
                Text("QA").font(.caption2).padding(4).background(MountainStyle.ink)
                    .accessibilityLabel("Private Mountain QA").accessibilityIdentifier("mountain-private-qa")
            }
#else
            if MountainExperience.isQAActive {
                Text("QA").font(.caption2).padding(4).background(MountainStyle.ink)
                    .accessibilityLabel("Private Mountain QA").accessibilityIdentifier("mountain-private-qa")
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
#if os(iOS)
        .statusBarHidden(!showStatusBar)
#endif
        .onChange(of: firstName) { refreshHistory() }
        .onChange(of: secondName) { refreshHistory() }
    }

    private var home: some View {
        Group {
            if social {
                socialHub
            } else {
                landing
            }
        }
        .foregroundStyle(MountainStyle.cream).tint(MountainStyle.gold).preferredColorScheme(.dark)
    }

    private var landing: some View {
        GeometryReader { geometry in
            ZStack {
                MountainScenery(active: !playing && !options && !rules)
                    .overlay(MountainStyle.ink.opacity(0.5))
                ScrollView {
                    VStack(spacing: 32) {
                        Spacer(minLength: 16)
                        Text("Race to\nDog Mountain")
                            .font(MountainStyle.display(typeSize.isAccessibilitySize ? 36 : geometry.size.width > 600 ? 76 : 48))
                            .tracking(-1).multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        Spacer(minLength: 40)
                        Button { startLocal() } label: {
                            Text("Play").font(.largeTitle.bold())
                                .frame(maxWidth: .infinity, minHeight: 64)
                        }
                        .buttonStyle(MountainButton(prominent: true))
                        .accessibilityIdentifier("start-game")
                        .keyboardShortcut("n", modifiers: .command)
                        HStack(spacing: 24) {
                            homeControl("How to play", symbol: "questionmark", identifier: "help") { rules = true }
                            Spacer(minLength: 0)
                            homeControl("Play with friends and saved games", symbol: "person.2.fill", identifier: "friends-and-games") { social = true }
                            Spacer(minLength: 0)
                            homeControl("Settings", symbol: "gearshape.fill", identifier: "game-options") { options = true }
                        }
                        Spacer(minLength: 16)
                    }
                    .padding(28)
                    .frame(maxWidth: 620, minHeight: geometry.size.height)
                    .frame(maxWidth: .infinity)
                }.scrollIndicators(.hidden)
            }
        }
    }

    private func homeControl(_ title: String, symbol: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.title2.weight(.semibold))
                .frame(width: 60, height: 60)
                .background(MountainStyle.ink, in: Circle())
                .overlay { Circle().strokeBorder(MountainStyle.cream.opacity(0.5), lineWidth: 1) }
        }
        .buttonStyle(.plain).mountainHover()
        .accessibilityLabel(title).accessibilityIdentifier(identifier).help(title)
    }

    private var socialHub: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    socialActions
                    gamesInbox
                }
                .padding(28).frame(maxWidth: 760).frame(maxWidth: .infinity)
            }
            .background(MountainStyle.ink)
            .navigationTitle("Friends & games").mountainInlineTitle()
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { social = false } } }
        }
    }

    private var localGame: some View {
        MountainGameView(size: size, names: names, computers: [firstAI, secondAI], difficulty: difficulty,
                         adjustment: 0, saved: selection, learningStore: learningStore, onSave: library.save,
                         onLeave: { playing = false; refreshHistory() })
#if os(iOS)
            .statusBarHidden(!showStatusBar)
#endif
    }
    private func startLocal(passAndPlay: Bool = false) {
        let computers = passAndPlay ? [false, false] : [firstAI, secondAI]
        let key = learningKey(computers: computers)
        let context = adaptiveDifficulty ? key.map { learningStore.begin(key: $0) } : nil
        let profile = context.map { learningStore.learning(for: $0.key).difficulty } ?? manualDifficulty
        var next = SavedMountainGame(size: size, names: names, computers: computers, difficulty: profile, adjustment: 0)
        next.learning = context
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
                    MountainMatchRow(title: race.title, subtitle: race.problem != nil ? "Refresh needed · Game Center" : race.yourTurn ? "Your move · Game Center" : "Waiting for a friend · Game Center", scores: race.challenge?.game.scores, symbol: "person.2.fill", needsMove: race.yourTurn && race.problem == nil) { Task { await friends.open(race.id) } }
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
                        MountainMatchRow(title: saved.title, subtitle: "Finished · Local", scores: saved.game.scores, symbol: "flag.checkered") { resume(saved) }.accessibilityIdentifier("finished-local-" + saved.id.uuidString)
                    }
                }.padding(.top, 12)
            }
            if let error = library.error { Text(error).font(.footnote).foregroundStyle(MountainStyle.gold) }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var manualDifficulty: ComputerDifficulty { ComputerDifficulty(rawValue: computerLevel) ?? .level1 }
    private func learningKey(computers: [Bool]) -> String? {
        guard computers.filter({ $0 }).count == 1, let human = computers.firstIndex(of: false) else { return nil }
        return MountainLearningStore.key(name: names[human], size: size, seat: human)
    }
    private var difficulty: ComputerDifficulty {
        if adaptiveDifficulty, let key = learningKey(computers: [firstAI, secondAI]) {
            return learningStore.learning(for: key).difficulty
        }
        return manualDifficulty
    }
    private var names: [String] { [clean(firstName, fallback: "Player 1"), clean(secondName, fallback: "Player 2")] }
    private func clean(_ name: String, fallback: String) -> String {
        let result = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? fallback : String(result.prefix(60))
    }
    private func refreshHistory() {
        history = [0, 1].map { MountainExperience.defaults.integer(forKey: "\(names[$0])vvv\(names[1 - $0])") }
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
                            if firstAI != secondAI {
                                Toggle("Adaptive difficulty", isOn: $adaptiveDifficulty)
                                    .accessibilityIdentifier("adaptive-difficulty")
                                if adaptiveDifficulty, let key = learningKey(computers: [firstAI, secondAI]) {
                                    Text("Starts easy and adjusts between games: slowly harder after sustained wins, easier faster after losses. Aims for about 60–70% wins; results will vary.")
                                        .font(.footnote)
                                    Text("Next game · \(difficulty.title)").font(.headline)
                                    if let rate = learningStore.learning(for: key).winRate {
                                        Text("Recent wins · \(Int((rate * 100).rounded()))% of completed, decisive games")
                                            .font(.footnote)
                                    }
                                    Button("Reset learning for this player & board") { resetLearning = true }
                                        .frame(minHeight: 44).accessibilityIdentifier("reset-learning")
                                }
                            }
                            if !adaptiveDifficulty || firstAI == secondAI {
                                Stepper(value: $computerLevel, in: 0...15) {
                                    Text("Difficulty · \(manualDifficulty.title) of 16").font(.headline).monospacedDigit()
                                }.accessibilityIdentifier("computer-difficulty")
                                Picker("Choose an opponent", selection: $computerLevel) {
                                    ForEach(ComputerDifficulty.allCases) { profile in
                                        Text("\(profile.title) · \(profile.name)").tag(profile.rawValue)
                                    }
                                }.pickerStyle(.menu)
                                Text("Manual difficulty stays fixed. Changes apply to new games.").font(.footnote)
                            }
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
                    Stepper(value: $boardScrollThreshold, in: 4...14) {
                        Text("Fit compact boards up to \(boardScrollThreshold) × \(boardScrollThreshold)")
                            .fixedSize(horizontal: false, vertical: true)
                    }.accessibilityIdentifier("board-scroll-threshold")
                    Text("Larger compact boards scroll to keep tiles easy to tap. Roomier layouts fit the whole board. Fitted tiles can be smaller than 44 points. Higher limits and narrow windows make smaller numbers; full values remain available to VoiceOver.").font(.footnote)
                    Text("Bigger board, more possibilities. Classic rules, every time.").font(.subheadline)
                    MountainExperienceOptions()
                    HStack {
                        Text("Head to head").font(.headline)
                        Spacer()
                        Text("\(history[0]) : \(history[1])").monospacedDigit().foregroundStyle(MountainStyle.gold)
                    }
#if os(iOS)
                    Toggle("Show Status Bar", isOn: $showStatusBar)
                        .accessibilityIdentifier("show-status-bar")
#endif
                    Link("Privacy Policy", destination: URL(string: "https://nathanfennel.com/race-to-dog-mountain/privacy.html")!).font(.footnote).frame(minHeight: 44)
                }.padding(28).frame(maxWidth: 620).frame(maxWidth: .infinity)
            }
            .background(MountainStyle.ink).navigationTitle("Settings").mountainInlineTitle()
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { options = false } } }
        }.tint(MountainStyle.gold).foregroundStyle(MountainStyle.cream).preferredColorScheme(.dark)
            .confirmationDialog("Reset learning?", isPresented: $resetLearning, titleVisibility: .visible) {
                Button("Reset learning", role: .destructive) {
                    if let key = learningKey(computers: [firstAI, secondAI]) { learningStore.reset(key: key) }
                }
            } message: { Text("The next game for this player, board size and role starts easy. Current games keep their difficulty.") }
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
                    instruction("flag.checkered", "Finish on top", "Used tiles stay empty. When the next player has no moves, the higher score wins. Starting order is random in computer games. Computer-only games wait until you tap Play.", MountainStyle.cream)
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
    @AppStorage("humanProfiles.v1", store: MountainExperience.defaults) private var humanProfiles = Data()
    @AppStorage("hapticsEnabled", store: MountainExperience.defaults) private var hapticsEnabled = true
    @Environment(\.scenePhase) private var scenePhase
    @State private var displayHub = MountainDisplayHub.shared
    @State private var customizing: MountainHumanSelection?
    @State private var resultPresented = false
    @State private var pendingResult = false
    @State private var feedback: [MountainMoveFeedback] = []
    @State private var moveIntensity = 0.2
    @State private var difficulty: ComputerDifficulty
    let learningStore: MountainLearningStore?
    let onLeave: (() -> Void)?
    let onSave: ((SavedMountainGame) -> Void)?
    @State private var savedID: UUID
    @AppStorage("adaptiveDifficulty", store: MountainExperience.defaults) private var adaptiveDifficulty = true
    @AppStorage("computerLevel", store: MountainExperience.defaults) private var computerLevel = 5
    @State private var learning: MountainLearningContext?
    @AppStorage("computerDialogue", store: MountainExperience.defaults) private var computerDialogue = false
    @State private var boardTop: CGFloat = 0
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
    @State private var history: MountainHistory?
    @State private var resolution: UUID?
    @State private var sharing = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage("animationsEnabled", store: MountainExperience.defaults) private var animationsEnabled = true
    private var reduceMotion: Bool { systemReduceMotion || !animationsEnabled }
    @Environment(\.dynamicTypeSize) private var typeSize

    init(size: Int, names: [String], computers: [Bool], difficulty: ComputerDifficulty, adjustment: Int, saved: SavedMountainGame? = nil, learningStore: MountainLearningStore? = nil, onSave: ((SavedMountainGame) -> Void)? = nil, onLeave: (() -> Void)? = nil) {
        self.names = saved?.names ?? names
        self.onLeave = onLeave; self.onSave = onSave
        self.learningStore = learningStore
        _difficulty = State(initialValue: saved?.difficulty ?? difficulty)
        _learning = State(initialValue: saved?.learning)
        _savedID = State(initialValue: saved?.id ?? UUID())
        _recorded = State(initialValue: saved?.recorded ?? false)
        _computerStarted = State(initialValue: saved?.computerStarted ?? computers.contains(false))
        _rolesChanged = State(initialValue: saved?.rolesChanged ?? false)
        _lastComputerMove = State(initialValue: saved?.replay)
        _matchAdjustment = State(initialValue: saved?.adjustment ?? adjustment)
        // Each presentation owns a fresh game and a snapshot of player settings.
        let initial = saved?.game ?? MountainGame(size: size, firstPlayer: MountainGame.randomStartingPlayer(computers: computers))
        _game = State(initialValue: initial)
        _history = State(initialValue: saved == nil ? MountainHistory(initial: initial) : saved?.history)
        _computers = State(initialValue: saved?.computers ?? computers)
    }

    private var gameContent: some View {
        GeometryReader { geometry in
            ZStack {
                MountainScenery(active: !replaying && !confirmExit, celebration: humanVictory)
                MountainStyle.ink.opacity(0.60).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 24) {
                        header
                        if usesSideControls(width: geometry.size.width, height: geometry.size.height) && !typeSize.isAccessibilitySize {
                            HStack(alignment: .top, spacing: 24) {
                                VStack(spacing: 18) {
                                    score(player: 0)
                                    score(player: 1)
                                    turnLabel
                                    startComputerButton
                                    matchControls
                                }.frame(width: 240)
                                board(width: max(160, min(min(geometry.size.width, 1268) - gameHorizontalPadding - 264, geometry.size.height - 128)), fitAllSizes: geometry.size.width >= 900 && geometry.size.height >= 600)
                                    .frame(maxWidth: .infinity)
                            }
                        } else {
                            verticalGame(width: min(geometry.size.width - 32, 760), maxHeight: geometry.size.width >= 600 && !typeSize.isAccessibilitySize ? max(160, geometry.size.height - boardTop - gameHorizontalPadding) : nil)
                        }
                    }
                    .coordinateSpace(name: "mountain-game-content")
                    .onPreferenceChange(MountainBoardTop.self) { boardTop = $0 }
#if os(visionOS)
                    .padding(32).frame(maxWidth: 1268)
#else
                    .padding(16)
#endif
                        .frame(maxWidth: 1268)
                        .frame(maxWidth: .infinity)
                }.scrollIndicators(.hidden)
            }
            .overlayPreferenceValue(MountainMoveAnchors.self) { anchors in
                GeometryReader { proxy in
                    if !reduceMotion {
                        ForEach(feedback) { event in
                            if let source = anchors[.tile(event.tile)], let target = anchors[.score(event.player)] {
                                MountainMoveVisual(event: event,
                                    start: CGPoint(x: proxy[source].midX, y: proxy[source].midY),
                                    end: CGPoint(x: proxy[target].midX, y: proxy[target].midY))
                            }
                        }
                    }
                }.allowsHitTesting(false).accessibilityHidden(true)
            }
            .task(id: feedback.last?.id) {
                guard !feedback.isEmpty else { return }
                do { try await Task.sleep(for: .milliseconds(650)) } catch { return }
                feedback.removeAll()
            }
            .onChange(of: scenePhase) { _, phase in if phase != .active { feedback.removeAll() }; publishDisplay() }
            .onChange(of: reduceMotion) { _, reduced in if reduced { feedback.removeAll() } }
            .sheet(item: $customizing) { player in MountainHumanEditor(identity: names[player.id], profiles: $humanProfiles).mountainSheetSize() }
            .sheet(isPresented: $resultPresented) { resultPanel.mountainSheetSize() }
            .onAppear { displayHub.claim(owner: savedID); if game.isOver { resultPresented = true }; publishDisplay() }
            .onChange(of: humanProfiles) { publishDisplay() }
            .onChange(of: customizing?.id) { publishDisplay(); presentPendingResult() }
            .onChange(of: replaying) { publishDisplay() }
            .onChange(of: confirmExit) { publishDisplay() }
            .confirmationDialog("Leave this game?", isPresented: $confirmExit, titleVisibility: .visible) {
                Button("Back to games") { leaveGame() }
            } message: { Text("Your progress is saved. You can finish this game later.") }

        }
    }
    var body: some View {
        gameContent
            .onReceive(NotificationCenter.default.publisher(for: MountainPlatform.didBecomeActive)) { _ in foregroundNonce += 1 }
            .task(id: "\(savedID)-\(game.moves)-\(computers)-\(confirmExit)-\(foregroundNonce)-\(computerStarted)-\(replaying)-\(customizing?.id ?? -1)-\(resultPresented)-\(resolution?.uuidString ?? "ready")-\(scenePhase)") {
                guard scenePhase == .active, MountainPlatform.isActive, !confirmExit, !replaying, customizing == nil, !resultPresented, resolution == nil, !waitingForStart, !game.isOver, computers[game.turn] else { return }
                do { try await Task.sleep(for: .milliseconds(700)) } catch { return }
                let snapshot = game, profile = difficulty, skill = matchAdjustment
                let next = await Task.detached(priority: .userInitiated) {
                    snapshot.computerMove(difficulty: profile, adjustment: skill)
                }.value
                guard !Task.isCancelled, !confirmExit, !replaying, customizing == nil, !resultPresented, resolution == nil, scenePhase == .active, MountainPlatform.isActive, game.moves == snapshot.moves, computers[game.turn] else { return }
                if let next { move(next, computer: true) }
            }
            .onChange(of: game.isOver) { _, over in if over { recordWin(); pendingResult = true; presentPendingResult() } }
            .onChange(of: computers) { rolesChanged = true; persist() }
            .onChange(of: computerStarted) { persist() }
            .onDisappear { retireDisplay() }
            .task(id: resolution) {
                guard let token = resolution else { return }
                do { try await Task.sleep(for: .seconds(MountainExperience.computerDuration)) } catch { return }
                guard !Task.isCancelled, resolution == token else { return }
                resolution = nil
            }
            .onChange(of: resolution) { _, _ in presentPendingResult() }
            .onChange(of: scenePhase) { _, phase in if phase != .active { resolution = nil } else { presentPendingResult() } }
            .onChange(of: confirmExit) { _, opened in if opened { resolution = nil } else { presentPendingResult() } }
            .onChange(of: replaying) { _, opened in if opened { resolution = nil } else { presentPendingResult() } }
            .sheet(isPresented: $sharing) { MountainFinishShare(game: game, names: [playerName(0), playerName(1)], history: history) }
            .sheet(isPresented: $replaying) {
                if let replay = lastComputerMove { MountainReplayView(replay: replay).mountainSheetSize() }
            }
        .foregroundStyle(MountainStyle.cream).tint(MountainStyle.gold).preferredColorScheme(.dark)
        .mountainGameFeedback(moves: game.moves, over: humanVictory, enabled: hapticsEnabled, intensity: 0.2 + moveIntensity * 0.8)
        .offeringMountainDisplay()
#if os(macOS)
        .focusedSceneValue(\.mountainActions, MountainActions(newGame: { restart() }, replay: lastComputerMove == nil ? nil : { replaying = true }, close: { if game.isOver { leaveGame() } else { confirmExit = true } }))
#endif
    }
    private func usesSideControls(width: CGFloat, height: CGFloat) -> Bool {
#if os(macOS)
        width >= 620
#else
        width >= 650 && width > height
#endif
    }
    private var gameHorizontalPadding: CGFloat {
#if os(visionOS)
        64
#else
        32
#endif
    }
    private func board(width: CGFloat, maxHeight: CGFloat? = nil, fitAllSizes: Bool = false) -> some View {
        MountainBoard(game: game, availableWidth: width, availableHeight: maxHeight, fitAllSizes: fitAllSizes, interactive: !computers[game.turn] && resolution == nil, lastMove: lastMove, lastPoints: lastPoints, selected: resolution == nil ? nil : lastComputerMove?.tileID) { move($0) }
            .background { GeometryReader { proxy in
                Color.clear.preference(key: MountainBoardTop.self, value: proxy.frame(in: .named("mountain-game-content")).minY)
            } }
    }
    private func verticalGame(width: CGFloat, maxHeight: CGFloat? = nil) -> some View {
        VStack(spacing: 24) {
            if typeSize.isAccessibilitySize {
                VStack(spacing: 14) { score(player: 0); score(player: 1) }
            } else {
                HStack(spacing: 14) { score(player: 0); score(player: 1) }
            }
            turnLabel
            startComputerButton
            board(width: width, maxHeight: maxHeight)
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
                    Button("Results") { pendingResult = false; resultPresented = true }.buttonStyle(MountainButton(prominent: true)).accessibilityIdentifier("game-results")
                    Button("Back to mountain") { leaveGame() }.buttonStyle(MountainButton())
                }
            } else {
                Label("Every choice sets your rival’s next move.", systemImage: "point.topleft.down.to.point.bottomright.curvepath").font(.footnote)
            }
        }
    }
    private func presentPendingResult() {
        guard pendingResult, game.isOver, resolution == nil, scenePhase == .active,
              !confirmExit, !replaying, customizing == nil else { return }
        pendingResult = false; resultPresented = true
    }
    private func leaveGame() { persist(); if let onLeave { onLeave() } else { dismiss() } }
    private var waitingForStart: Bool { game.moves == 0 && computers[game.turn] && !computerStarted }
    private func playerName(_ index: Int) -> String { computers[index] ? difficulty.name : MountainHumanProfile.read(identity: names[index], data: humanProfiles).displayName }
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
            if resolution != nil {
                Label("\(difficulty.name) takes \(lastPoints) points", systemImage: "hand.point.up.left.fill")
                    .font(.headline).foregroundStyle(MountainStyle.gold)
                    .transition(.identity).transaction { $0.animation = nil }
                    .accessibilityIdentifier("computer-resolving")
            } else if game.isOver {
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
    private var humanVictory: Bool {
        game.isOver && game.scores[0] != game.scores[1] && !computers[game.scores[0] > game.scores[1] ? 0 : 1]
    }
    private var resultPanel: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: humanVictory ? "pawprint.fill" : "mountain.2.fill")
                        .font(.system(size: 56)).foregroundStyle(MountainStyle.gold).accessibilityHidden(true)
                    Text(result).font(MountainStyle.display(36)).multilineTextAlignment(.center).accessibilityAddTraits(.isHeader)
                    Text("\(playerName(0)) \(game.scores[0]) · \(playerName(1)) \(game.scores[1])")
                        .font(.title3.bold()).multilineTextAlignment(.center)
                    Button("Race again") { restart() }.buttonStyle(MountainButton(prominent: true)).accessibilityIdentifier("result-rematch")
                    NavigationLink { MountainFinishShare(game: game, names: [playerName(0), playerName(1)], history: history) } label: {
                        Label("Share", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                    }.buttonStyle(MountainButton()).accessibilityIdentifier("share-result")
                    Button("Back to mountain") { resultPresented = false; leaveGame() }.buttonStyle(MountainButton()).accessibilityIdentifier("result-home")
                }.padding(28).frame(maxWidth: 620).frame(maxWidth: .infinity)
            }.background(MountainStyle.ink).navigationTitle("Game over").mountainInlineTitle()
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("View board") { resultPresented = false } } }
        }.foregroundStyle(MountainStyle.cream).tint(MountainStyle.gold).preferredColorScheme(.dark)
    }
    private var result: String {
        game.scores[0] == game.scores[1] ? "A tie!" : "\(playerName(game.scores[0] > game.scores[1] ? 0 : 1)) wins!"
    }
    @ViewBuilder private func score(player: Int) -> some View {
        if computers[player] {
            scoreContents(player: player)
        } else {
            Button { customizing = MountainHumanSelection(id: player) } label: { scoreContents(player: player) }
                .buttonStyle(.plain).accessibilityIdentifier("human-profile-\(player)")
                .accessibilityLabel("\(playerName(player)), \(game.scores[player]) points. Customize profile")
        }
    }
    private func scoreContents(player: Int) -> some View {
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
                    Image(systemName: MountainHumanProfile.read(identity: names[player], data: humanProfiles).symbol).frame(width: 48, height: 48)
                        .background(MountainStyle.player(player).opacity(0.12), in: Circle()).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(playerName(player)).font(.subheadline.weight(.semibold)).lineLimit(2)
                        Text(player == 0 ? "Row player" : "Column player").font(.caption)
                    }
                }
            }
            MountainScoreNumber(value: Double(game.scores[player])).font(MountainStyle.display(40))
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: game.scores[player])
                .accessibilityLabel("\(game.scores[player])")
                .anchorPreference(key: MountainMoveAnchors.self, value: .bounds) { [.score(player): $0] }
            HStack(spacing: 6) {
                Image(systemName: player == 0 ? "arrow.left.and.right" : "arrow.up.and.down")
                Text(game.turn == player && !game.isOver ? computers[player] ? waitingForStart ? "Ready" : "Thinking" : "Your turn" : "Points")
            }.font(.caption.weight(.semibold))
                .transaction { $0.animation = nil }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(18)
            .foregroundStyle(MountainStyle.player(player))
            .background(MountainStyle.player(player).opacity(game.turn == player && !game.isOver ? 0.17 : 0.06), in: RoundedRectangle(cornerRadius: 16))
            .overlay(alignment: .bottom) {
                Capsule().fill(game.turn == player && !game.isOver ? MountainStyle.player(player) : .clear).frame(height: 3).padding(.horizontal, 18)
            }
            .accessibilityElement(children: .combine)
    }
    private func move(_ id: Int, computer: Bool = false) {
        guard resolution == nil, game.canPlay(id), computers[game.turn] == computer else { return }
        let event = MountainMoveFeedback(id: game.moves + 1, tile: id, player: game.turn, points: game.tiles[id].value, maximum: game.size * game.size)
        moveIntensity = event.intensity
        if !reduceMotion { feedback = Array((feedback + [event]).suffix(8)) }
        if computer { resolution = UUID() }
        _ = history?.record(id, before: game)
        if computer { lastComputerMove = MountainReplay(before: game, tileID: id, difficulty: difficulty) }
        lastPoints = game.tiles[id].value
        lastMove = id
        withAnimation(reduceMotion ? nil : .spring(response: computer ? MountainExperience.computerDuration : 0.34, dampingFraction: 0.8)) {
            _ = game.play(id)
        }
        if game.isOver { recordWin() }
        persist()
    }
    private func publishDisplay() {
#if os(iOS)
        displayHub.publish(MountainDisplaySnapshot(owner: savedID, game: game,
            names: [playerName(0), playerName(1)],
            symbols: [0, 1].map { computers[$0] ? "pawprint.fill" : MountainHumanProfile.read(identity: names[$0], data: humanProfiles).symbol },
            computers: computers, difficulty: difficulty, lastMove: lastMove, lastPoints: lastPoints,
            paused: scenePhase != .active || replaying || confirmExit || customizing != nil))
#endif
    }
    private func retireDisplay() {
        feedback.removeAll(); resolution = nil
        if displayHub.activeOwner == savedID { persist(publish: false); displayHub.clear(owner: savedID) }
    }
    private func persist(publish: Bool = true) {
        if publish { publishDisplay() }
        var saved = SavedMountainGame(size: game.size, names: names, computers: computers, difficulty: difficulty, adjustment: matchAdjustment)
        saved.id = savedID; saved.game = game; saved.replay = lastComputerMove
        saved.learning = learning
        saved.history = history
        saved.recorded = recorded; saved.computerStarted = computerStarted; saved.rolesChanged = rolesChanged
        onSave?(saved)
    }
    private func restart() {
        feedback.removeAll(); resultPresented = false; pendingResult = false
        savedID = UUID()
        displayHub.claim(owner: savedID)
        game = MountainGame(size: game.size, firstPlayer: MountainGame.randomStartingPlayer(computers: computers))
        resolution = nil; history = MountainHistory(initial: game)
        recorded = false; lastMove = nil; lastPoints = 0; lastComputerMove = nil
        computerStarted = computers.contains(false); rolesChanged = false; matchAdjustment = 0
        if adaptiveDifficulty, computers.filter({ $0 }).count == 1, let human = computers.firstIndex(of: false), let learningStore {
            let key = MountainLearningStore.key(name: names[human], size: game.size, seat: human)
            learning = learningStore.begin(key: key)
            difficulty = learningStore.learning(for: key).difficulty
        } else {
            learning = nil
            difficulty = ComputerDifficulty(rawValue: computerLevel) ?? .level1
        }
        foregroundNonce += 1; persist()
    }
    private func recordWin() {
        guard game.isOver, !recorded else { return }
        recorded = true
        if !rolesChanged, computers.filter({ $0 }).count == 1,
           let human = computers.firstIndex(of: false), let learning {
            let result: MountainLearning.Outcome = game.scores[0] == game.scores[1] ? .tie : game.scores[human] > game.scores[1 - human] ? .win : .loss
            learningStore?.record(result, gameID: savedID, context: learning)
        }
        guard game.scores[0] != game.scores[1] else { return }
        let winner = game.scores[0] > game.scores[1] ? 0 : 1
        let key = "\(names[winner])vvv\(names[1 - winner])"
        MountainExperience.defaults.set(MountainExperience.defaults.integer(forKey: key) + 1, forKey: key)
    }
}

private struct OpponentPortrait: View {
    let difficulty: ComputerDifficulty
    var size: CGFloat = 64
    var thinking = false
    var reaction = 0
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage("animationsEnabled", store: MountainExperience.defaults) private var animationsEnabled = true
    private var reduceMotion: Bool { systemReduceMotion || !animationsEnabled }
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
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage("animationsEnabled", store: MountainExperience.defaults) private var animationsEnabled = true
    private var reduceMotion: Bool { systemReduceMotion || !animationsEnabled }
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

private struct MountainBoardTop: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

private struct MountainHumanSelection: Identifiable { let id: Int }
private struct MountainHumanEditor: View {
    let identity: String
    @Binding var profiles: Data
    @State private var name = ""
    @State private var symbol = "person.fill"
    @Environment(\.dismiss) private var dismiss
    private let labels = ["Person", "Paw print", "Leaf", "Sun", "Mountain", "Sparkles"]
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    TextField("Display name", text: $name).textFieldStyle(.roundedBorder).accessibilityIdentifier("profile-display-name")
                    Text("Your icon").font(.headline)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 16) {
                        ForEach(MountainHumanProfile.symbols, id: \.self) { choice in
                            Button { symbol = choice } label: {
                                Image(systemName: choice).font(.title2).frame(width: 60, height: 60)
                                    .background(symbol == choice ? MountainStyle.gold : MountainStyle.cream.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                                    .foregroundStyle(symbol == choice ? MountainStyle.ink : MountainStyle.cream)
                            }.buttonStyle(.plain)
                                .accessibilityLabel(labels[MountainHumanProfile.symbols.firstIndex(of: choice)!])
                                .accessibilityAddTraits(symbol == choice ? .isSelected : [])
                        }
                    }
                }.padding(28).frame(maxWidth: 620).frame(maxWidth: .infinity)
            }.background(MountainStyle.ink).navigationTitle("Your profile").mountainInlineTitle()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") {
                        if let data = MountainHumanProfile.updating(identity: identity, displayName: name, symbol: symbol, data: profiles) { profiles = data; dismiss() }
                    }.accessibilityIdentifier("save-profile") }
                }
        }.foregroundStyle(MountainStyle.cream).tint(MountainStyle.gold).preferredColorScheme(.dark)
            .onAppear { let profile = MountainHumanProfile.read(identity: identity, data: profiles); name = profile.displayName; symbol = profile.symbol }
    }
}

#if os(iOS)
@objc(DMExternalMountainSceneDelegate)
final class MountainExternalSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(rootView: MountainExternalScreen())
        window.isUserInteractionEnabled = false
        self.window = window
        MountainDisplayHub.shared.connected(session.persistentIdentifier)
        window.isHidden = false
    }
    func sceneDidDisconnect(_ scene: UIScene) {
        MountainDisplayHub.shared.disconnected(scene.session.persistentIdentifier)
        window?.isHidden = true; window = nil
    }
}

private struct MountainExternalScreen: View {
    @State private var hub = MountainDisplayHub.shared
    var body: some View {
        Group {
            if let snapshot = hub.snapshot {
                MountainExternalPresentation(snapshot: snapshot).id(snapshot.owner)
            } else {
                ZStack {
                    MountainScenery().overlay(MountainStyle.ink.opacity(0.5)).ignoresSafeArea()
                    VStack(spacing: 24) {
                        Image(systemName: "mountain.2.fill").font(.system(size: 80)).foregroundStyle(MountainStyle.gold)
                        Text("Race to Dog Mountain").font(MountainStyle.display(60)).multilineTextAlignment(.center)
                        Text("Start a game on your iPhone or iPad").font(.title)
                    }.padding(48)
                }.foregroundStyle(MountainStyle.cream)
            }
        }.preferredColorScheme(.dark).statusBarHidden()
    }
}

#if !targetEnvironment(macCatalyst)
private struct MountainSceneAccessory: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> MountainAccessoryController { MountainAccessoryController() }
    func updateUIViewController(_ controller: MountainAccessoryController, context: Context) {}
}

private final class MountainAccessoryController: UIViewController {
    private var registration: AnyObject?
    override func viewDidLoad() { super.viewDidLoad(); view.isUserInteractionEnabled = false }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if #available(iOS 27, *), registration == nil {
            let configuration = UISceneConfiguration(name: "Mountain Display", sessionRole: .windowExternalDisplayNonInteractive)
            configuration.delegateClass = MountainExternalSceneDelegate.self
            registration = registerSceneAccessory(.externalNonInteractive(sceneConfiguration: configuration))
        }
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if #available(iOS 27, *), let registration = registration as? UISceneAccessoryRegistration {
            unregisterSceneAccessory(registration)
        }
        registration = nil
    }
}
#endif
#endif

private extension View {
    @ViewBuilder func offeringMountainDisplay() -> some View {
#if os(iOS) && !targetEnvironment(macCatalyst)
        background { MountainSceneAccessory().frame(width: 0, height: 0) }
#else
        self
#endif
    }
}

private struct MountainExperienceOptions: View {
    @AppStorage("animationsEnabled", store: MountainExperience.defaults) private var animations = true
    @AppStorage("hapticsEnabled", store: MountainExperience.defaults) private var haptics = true
    @AppStorage("computerMoveDuration", store: MountainExperience.defaults) private var duration = 0.7
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Game feedback").font(.headline)
            Toggle("Animations", isOn: $animations).accessibilityIdentifier("animations-setting")
            Toggle("Haptics", isOn: $haptics).accessibilityIdentifier("haptics-setting")
            Picker("Computer move", selection: $duration) {
                Text("Fast · 0.4 s").tag(0.4)
                Text("Natural · 0.7 s").tag(0.7)
                Text("Relaxed · 1.2 s").tag(1.2)
            }.accessibilityIdentifier("computer-speed-setting")
            Text("Reduce Motion keeps moves clear without movement. Haptics play on supported devices.").font(.footnote)
        }
    }
}

struct MountainFinishShare: View {
    let game: MountainGame
    let names: [String]
    let history: MountainHistory?
    @Environment(\.dismiss) private var dismiss
    @State private var exported: URL?
    @State private var failure: String?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "flag.checkered").font(.largeTitle).foregroundStyle(MountainStyle.gold)
                    Text("Share your climb").font(MountainStyle.display(28))
                    if let exported {
                        ShareLink(item: exported, subject: Text("Race to Dog Mountain"), message: Text("Race to Dog Mountain · https://apps.apple.com/app/id971329310")) {
                            Label(history == nil ? "Share final board" : "Share replay GIF", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                        }.buttonStyle(MountainButton(prominent: true)).accessibilityIdentifier("share-export")
                    } else if let failure { Text(failure).font(.body) }
                    else { ProgressView("Preparing your actual game…") }
                    Text(history == nil ? "This older save has no full move history. Its actual final board is shared as an image." : "Every frame follows the numbers played in this game.")
                        .font(.subheadline).multilineTextAlignment(.center)
                }.padding(28).frame(maxWidth: 620).frame(maxWidth: .infinity)
            }.background(MountainStyle.ink)
                .navigationTitle("Share").mountainInlineTitle()
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() }.accessibilityIdentifier("close-share") } }
        }.foregroundStyle(MountainStyle.cream).tint(MountainStyle.gold).preferredColorScheme(.dark)
            .task {
                do { exported = try await MountainGameExporter.export(game: game, names: names, history: history) }
                catch { if !Task.isCancelled { failure = "The replay couldn't be prepared. Your saved game is unchanged." } }
            }
    }
}

@MainActor private enum MountainGameExporter {
    enum ExportError: Error { case invalidHistory, render, fileLimit }
    static func export(game: MountainGame, names: [String], history: MountainHistory?) async throws -> URL {
        guard game.isValid, game.isOver, names.count == 2 else { throw ExportError.invalidHistory }
        let states: [MountainGame]
        if let history {
            guard history.matches(game), let verified = history.states, verified.count <= 197 else { throw ExportError.invalidHistory }
            states = verified
        } else { states = [game] }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("mountain-share-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(history == nil ? "Dog-Mountain-final.png" : "Dog-Mountain-replay.gif")
        var completed = false
        defer { if !completed { try? FileManager.default.removeItem(at: folder) } }
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, (history == nil ? UTType.png.identifier : UTType.gif.identifier) as CFString, states.count, nil) else { throw ExportError.render }
        if history != nil {
            CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        }
        for (index, state) in states.enumerated() {
            try Task.checkCancellation()
            let selected = index > 0 ? history?.choices[index - 1] : nil
            let points = selected.map { history!.initial.tiles[$0].value } ?? 0
            let renderer = ImageRenderer(content: MountainExportBoard(game: state, names: names, selected: selected, points: points)
                .environment(\.dynamicTypeSize, .medium).environment(\.colorScheme, .dark))
            renderer.scale = 1
            guard let pixels = renderer.cgImage else { throw ExportError.render }
            let delay = index == states.count - 1 ? 2.0 : index == 0 ? 0.8 : 0.45
            CGImageDestinationAddImage(destination, pixels, history == nil ? nil : [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay]] as CFDictionary)
            await Task.yield()
        }
        guard CGImageDestinationFinalize(destination),
              let bytes = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize, bytes <= 16 * 1024 * 1024 else { throw ExportError.fileLimit }
        completed = true
        return url
    }
}

/// A native export of real game state, not a reconstruction of missing history.
private struct MountainExportBoard: View {
    let game: MountainGame
    let names: [String]
    let selected: Int?
    let points: Int
    private var side: CGFloat { (448 - CGFloat(game.size - 1) * 3) / CGFloat(game.size) }
    var body: some View {
        VStack(spacing: 12) {
            Text("Race to Dog Mountain").font(MountainStyle.display(28))
            HStack {
                ForEach(0..<2, id: \.self) { player in
                    VStack(spacing: 4) {
                        Text(names[player]).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                        Text("\(game.scores[player])").font(.system(size: 24, weight: .bold)).monospacedDigit()
                    }.frame(maxWidth: .infinity).foregroundStyle(MountainStyle.player(player))
                }
            }
            Text(game.isOver ? game.scores[0] == game.scores[1] ? "A tie!" : "\(names[game.scores[0] > game.scores[1] ? 0 : 1]) wins!" : selected == nil ? "The climb begins" : "+\(points) points · Move \(game.moves)")
                .font(.system(size: 16, weight: .semibold)).lineLimit(1)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(side), spacing: 3), count: game.size), spacing: 3) {
                ForEach(game.tiles) { tile in
                    Text(tile.value == 0 ? selected == tile.id ? "+\(points)" : "·" : "\(tile.value)")
                        .font(.system(size: game.size > 8 ? 12 : 19, weight: .bold)).monospacedDigit()
                        .frame(width: side, height: side)
                        .foregroundStyle(tile.value == 0 ? MountainStyle.cream : MountainStyle.ink)
                        .background(tile.value == 0 ? MountainStyle.cream.opacity(0.08) : game.canPlay(tile.id) ? MountainStyle.player(game.turn) : MountainStyle.cream, in: RoundedRectangle(cornerRadius: 5))
                        .overlay { RoundedRectangle(cornerRadius: 5).strokeBorder(selected == tile.id ? MountainStyle.gold : .clear, lineWidth: 2) }
                }
            }.frame(width: 448)
            Text("Classic · \(game.size) × \(game.size)\napps.apple.com/app/id971329310").font(.system(size: 11)).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }.padding(24).frame(width: 512, height: 760).background(MountainStyle.ink).foregroundStyle(MountainStyle.cream)
    }
}
