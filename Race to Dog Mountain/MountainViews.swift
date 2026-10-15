import SwiftUI
import Observation
import ImageIO
import UniformTypeIdentifiers
#if canImport(PhotosUI)
import PhotosUI
#endif
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
    @State private var playing = false
    @State private var selection: SavedMountainGame?
    @State private var library = MountainLibrary()
    @State private var learningStore = MountainLearningStore.shared
#if os(iOS)
    @State private var friends = MountainPhoneCoordinator.shared.friends
#else
    @State private var friends = MountainFriends()
#endif
    @Environment(\.scenePhase) private var phase
    @State private var options = false
    @State private var rules = false
    @State private var startAfterGuide = false
    @State private var social = false
    @Environment(\.openURL) private var openURL
    @State private var gameCategory = MountainGameCategory.passAndPlay
    @AppStorage("humanProfiles.v1", store: MountainExperience.defaults) private var humanProfiles = Data()
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
        .sheet(isPresented: $rules, onDismiss: { if startAfterGuide { startAfterGuide = false; startLocal() } }) {
            MountainRules { startAfterGuide = true; rules = false }.mountainSheetSize()
        }
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
                MountainScenery(active: !playing && !options && !rules, followsLocalTime: true)
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
                VStack(alignment: .leading, spacing: 24) {
                    Picker("Game type", selection: $gameCategory) {
                        ForEach(MountainGameCategory.allCases) { category in Text(category.title).tag(category) }
                    }.pickerStyle(.segmented).accessibilityIdentifier("games-category")
                    gamesInbox
                }.padding(20).frame(maxWidth: 760).frame(maxWidth: .infinity)
            }.background(MountainStyle.ink).navigationTitle("Your Games").mountainInlineTitle()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        NavigationLink { gameCenterGames } label: { Image(systemName: "person.2.fill").frame(minWidth: 44, minHeight: 44) }
                            .accessibilityLabel("Game Center friends").accessibilityIdentifier("game-center-games")
                    }
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { social = false } }
                }
        }
    }
    private var gameCenterGames: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Button { friends.invite(size: size) } label: { Label("Play a friend", systemImage: "person.2.fill").frame(maxWidth: .infinity) }
                    .buttonStyle(MountainButton(prominent: true)).disabled(friends.sending).accessibilityIdentifier("play-friend")
                ForEach(friends.active + friends.finished) { race in
                    MountainMatchRow(title: race.title, subtitle: race.problem != nil ? "Refresh needed" : race.ended ? "Finished" : race.yourTurn ? "Your move" : "Waiting for a friend", scores: race.challenge?.game.scores, symbol: "person.2.fill", needsMove: race.yourTurn && race.problem == nil) { Task { await friends.open(race.id) } }
                }
                Button { Task { await friends.refresh() } } label: { Label("Refresh", systemImage: "arrow.clockwise").frame(minHeight: 44) }.disabled(friends.loading)
                if friends.loading { ProgressView().tint(MountainStyle.gold) }
            }.padding(20).frame(maxWidth: 760).frame(maxWidth: .infinity)
        }.background(MountainStyle.ink).navigationTitle("Game Center").mountainInlineTitle()
    }
    private var categoryGames: [SavedMountainGame] { library.games.filter { $0.hasScore && $0.category == gameCategory }.sorted { $0.updatedAt > $1.updatedAt } }
    private var gamesInbox: some View {
        VStack(alignment: .leading, spacing: 16) {
            if gameCategory == .messages || categoryGames.isEmpty {
                Image(systemName: gameCategory == .messages ? "message.fill" : gameCategory == .ai ? "sparkles" : "person.2.fill")
                    .font(.largeTitle).foregroundStyle(MountainStyle.gold).frame(maxWidth: .infinity).accessibilityHidden(true)
                Text(gameCategory == .messages ? "Your iMessage games live in their conversations. Open a conversation, tap +, then choose Race to Dog Mountain." : gameCategory == .ai ? "Play a computer on this device. Tap its player card to choose a level." : "Share this device with a friend and take turns on the same board.")
                    .font(.body).multilineTextAlignment(.center).frame(maxWidth: .infinity)
            }
            Button { startCategoryGame() } label: { Label(gameCategory == .messages ? "Open Messages" : "New \(gameCategory.title) game", systemImage: gameCategory == .messages ? "message.fill" : "play.fill").frame(maxWidth: .infinity) }
                .buttonStyle(MountainButton(prominent: true)).accessibilityIdentifier("new-category-game")
            ForEach(categoryGames.filter { !$0.game.isOver }) { saved in savedRow(saved) }
            if categoryGames.contains(where: { $0.game.isOver }) {
                DisclosureGroup("Finished games") { ForEach(categoryGames.filter { $0.game.isOver }) { saved in savedRow(saved) } }
            }
            if let error = library.error { Text(error).font(.footnote).foregroundStyle(MountainStyle.gold) }
        }
    }
    private func savedRow(_ saved: SavedMountainGame) -> some View {
        MountainMatchRow(title: saved.names.enumerated().map { saved.computers[$0.offset] ? saved.difficulty.displayName : MountainHumanProfile.read(identity: $0.element, data: humanProfiles).displayName }.joined(separator: " & "),
                         subtitle: "\(saved.game.isOver ? "Finished · " : "")\(saved.game.size) × \(saved.game.size)", scores: saved.game.scores,
                         symbol: saved.computers.contains(true) ? "sparkles" : "person.2.fill", needsMove: !saved.game.isOver) { resume(saved) }
            .accessibilityIdentifier("saved-local-" + saved.id.uuidString)
    }
    private func startCategoryGame() {
        switch gameCategory {
        case .passAndPlay: startLocal(passAndPlay: true)
        case .ai: startLocal(againstComputer: true)
        case .messages:
            if let url = URL(string: "sms:") { openURL(url) }
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
    private func startLocal(passAndPlay: Bool = false, againstComputer: Bool = false) {
        let computers = passAndPlay ? [false, false] : againstComputer ? [false, true] : [firstAI, secondAI]
        let key = learningKey(computers: computers)
        let context = adaptiveDifficulty ? key.map { learningStore.begin(key: $0) } : nil
        let profile = context.map { learningStore.learning(for: $0.key).difficulty } ?? manualDifficulty
        var next = SavedMountainGame(size: size, names: names, computers: computers, difficulty: profile, adjustment: 0)
        next.learning = context
        library.save(next); selection = next; playing = true
    }
    private func resume(_ game: SavedMountainGame) { selection = game; playing = true }
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
    private var playerOptions: some View { MountainSettings() }
}


private struct MountainRules: View {
    var onPlay: () -> Void
    @State private var lesson = MountainTutorial()
    @State private var feedback: [MountainMoveFeedback] = []
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("animationsEnabled", store: MountainExperience.defaults) private var animationsEnabled = true
    private let titles = ["Follow the gold row", "Now try the mint column", "Think one move ahead", "Leave a good path", "Ready for the mountain"]
    private let details = ["Tap a gold number. It adds to your score.", "Your choice set this column. Tap a mint number.", "Pick a gold number. Notice which column you leave.", "Take a mint number. Used tiles stay empty.", "When the next player has no moves, the higher score wins."]
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 16) {
                        MountainReservedText(lines: typeSize.isAccessibilitySize ? 4 : 2) { Text(titles[lesson.step]).id(lesson.step).transition(pageTransition) }
                            .font(.title2.bold()).multilineTextAlignment(.center)
                            .accessibilityAddTraits(.isHeader).accessibilityIdentifier("tutorial-heading")
                            .animation(pageAnimation, value: lesson.step)
                            .contentShape(Rectangle()).gesture(pageSwipe)
                        HStack(spacing: 16) { score(0); score(1) }
                        MountainBoard(game: lesson.game, availableWidth: boardSide(geometry.size), fitAllSizes: true,
                                      interactive: !lesson.finished, lastMove: lesson.lastMove,
                                      lastPoints: lesson.lastPoints) { choose($0) }
                            .accessibilityIdentifier("tutorial-board")
                        MountainReservedText(lines: typeSize.isAccessibilitySize ? 9 : 3) { Text(details[lesson.step]).id(lesson.step).transition(pageTransition) }
                            .font(.body).multilineTextAlignment(.center)
                            .animation(pageAnimation, value: lesson.step)
                            .contentShape(Rectangle()).gesture(pageSwipe)
                        HStack(spacing: 16) {
                            Button { navigate(lesson.step - 1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                                .disabled(lesson.step == 0).accessibilityLabel("Previous step").accessibilityIdentifier("tutorial-back")
                            HStack(spacing: 8) {
                                ForEach(0...MountainTutorial.lastStep, id: \.self) { page in
                                    Circle().fill(page == lesson.step ? MountainStyle.gold : MountainStyle.cream.opacity(0.25)).frame(width: 7, height: 7)
                                }
                            }.frame(maxWidth: .infinity).accessibilityElement(children: .ignore)
                                .accessibilityLabel("Step \(lesson.step + 1) of \(MountainTutorial.lastStep + 1)")
                            Button { navigate(lesson.step + 1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                                .disabled(!lesson.canGoForward).accessibilityLabel("Next completed step").accessibilityIdentifier("tutorial-next")
                        }
                        Button(action: onPlay) { Text("Play").frame(maxWidth: .infinity) }
                            .buttonStyle(MountainButton(prominent: true))
                            .opacity(lesson.finished ? 1 : 0).disabled(!lesson.finished).accessibilityHidden(!lesson.finished)
                            .accessibilityIdentifier("tutorial-finish")
                    }.padding(16).frame(maxWidth: 520).frame(maxWidth: .infinity)
                }.scrollIndicators(.hidden)
                    .overlayPreferenceValue(MountainMoveAnchors.self) { anchors in
                        MountainMoveEffects(events: $feedback, anchors: anchors, reduceMotion: reduceMotion || !animationsEnabled)
                    }
            }.background(MountainStyle.ink).navigationTitle("How to play").mountainInlineTitle()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { dismiss() } label: { Image(systemName: "xmark").frame(minWidth: 44, minHeight: 44) }
                            .accessibilityLabel("Close guide").accessibilityIdentifier("close-tutorial")
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        if !lesson.finished {
                            Button(action: onPlay) { Label("Play", systemImage: "play.fill").frame(minHeight: 44) }
                                .accessibilityIdentifier("tutorial-play")
                        }
                    }
                }
        }.foregroundStyle(MountainStyle.cream).tint(MountainStyle.gold).preferredColorScheme(.dark)
    }
    private var pageAnimation: Animation? { reduceMotion || !animationsEnabled ? nil : .easeInOut(duration: 0.25) }
    private var pageTransition: AnyTransition { reduceMotion || !animationsEnabled ? .identity : .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)) }
    private var pageSwipe: some Gesture {
        DragGesture(minimumDistance: 35).onEnded { value in
            guard abs(value.translation.width) > abs(value.translation.height) else { return }
            navigate(lesson.step + (value.translation.width < 0 ? 1 : -1))
        }
    }
    private func boardSide(_ size: CGSize) -> CGFloat { min(max(176, size.height * 0.44), min(400, size.width - 32)) }
    private func navigate(_ step: Int) { feedback.removeAll(); lesson.navigate(to: step) }
    private func choose(_ tile: Int) {
        let before = lesson.game
        guard lesson.choose(tile) else { return }
        if !reduceMotion && animationsEnabled {
            feedback = MountainMoveFeedback(id: lesson.step, tile: tile, player: before.turn,
                                            points: before.tiles[tile].value, maximum: 16).adding(to: feedback)
        }
    }
    private func score(_ player: Int) -> some View {
        HStack(spacing: 12) {
            Text(player == 0 ? "You" : "Friend").font(.subheadline.bold())
            Spacer(minLength: 4)
            MountainReservedText { MountainScoreNumber(value: Double(lesson.game.scores[player])) }
                .font(.title2.bold()).frame(width: 48)
                .anchorPreference(key: MountainMoveAnchors.self, value: .bounds) { [.score(player): $0] }
        }.padding(12).foregroundStyle(MountainStyle.player(player))
            .background(MountainStyle.player(player).opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
            .overlay { MountainPlayerHighlight(player: player, active: lesson.game.turn == player && !lesson.finished) }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(player == 0 ? "You" : "Friend"), \(lesson.game.scores[player]) points. \(player == 0 ? "Row" : "Column") player")
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
    @State private var boardTop: CGFloat = 0
    @State private var matchAdjustment: Int
    @State private var rolesChanged = false
    @State private var computerStarted = false
    @State private var replaying = false
    @State private var lastComputerMove: MountainReplay?
    @State private var computers: [Bool]
    @State private var game: MountainGame
    @State private var recorded = false
    @State private var leavingGame = false
    @State private var foregroundNonce = 0
    @State private var lastMove: Int?
    @State private var lastPoints = 0
    @State private var history: MountainHistory?
    @State private var resolution: UUID?
    @State private var sharing = false
    @State private var gameHelp = false
    @State private var gameSettings = false
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
                MountainScenery(active: !replaying && !leavingGame, celebration: humanVictory)
                MountainStyle.ink.opacity(0.60).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 24) {
                        header
                        if usesSideControls(width: geometry.size.width, height: geometry.size.height) && !typeSize.isAccessibilitySize {
                            HStack(alignment: .top, spacing: 24) {
                                VStack(spacing: 18) {
                                    score(player: 0)
                                    score(player: 1)

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
                MountainMoveEffects(events: $feedback, anchors: anchors, reduceMotion: reduceMotion)
            }
            .onChange(of: geometry.size) { _, _ in feedback.removeAll() }
            .onChange(of: scenePhase) { _, phase in if phase != .active { feedback.removeAll() }; publishDisplay() }
            .onChange(of: reduceMotion) { _, reduced in if reduced { feedback.removeAll() } }
            .sheet(item: $customizing) { player in MountainHumanEditor(identity: names[player.id], profiles: $humanProfiles, computer: $computers[player.id], difficulty: $difficulty, adaptive: $adaptiveDifficulty, canResetLearning: computers.contains(false), onResetLearning: { if let human = computers[player.id] ? computers.firstIndex(of: false) : player.id { learningStore?.reset(key: MountainLearningStore.key(name: names[human], size: game.size, seat: human)) } }, onDifficultyChanged: { rolesChanged = true; learning = nil; computerLevel = difficulty.rawValue; persist() }).mountainSheetSize() }
            .sheet(isPresented: $resultPresented) { resultPanel.mountainSheetSize() }
            .onAppear { displayHub.claim(owner: savedID); if game.isOver { resultPresented = true }; publishDisplay() }
            .onChange(of: humanProfiles) { publishDisplay() }
            .onChange(of: customizing?.id) { publishDisplay(); presentPendingResult() }
            .onChange(of: replaying) { publishDisplay() }

        }
    }
    var body: some View {
        gameContent
            .onReceive(NotificationCenter.default.publisher(for: MountainPlatform.didBecomeActive)) { _ in foregroundNonce += 1 }
            .task(id: "\(savedID)-\(gameSettings)-\(gameHelp)-\(game.moves)-\(computers)-\(leavingGame)-\(foregroundNonce)-\(computerStarted)-\(replaying)-\(customizing?.id ?? -1)-\(resultPresented)-\(resolution?.uuidString ?? "ready")-\(scenePhase)") {
                guard scenePhase == .active, MountainPlatform.isActive, !leavingGame, !replaying, !gameHelp, !gameSettings, customizing == nil, !resultPresented, resolution == nil, !waitingForStart, !game.isOver, computers[game.turn] else { return }
                do { try await Task.sleep(for: .milliseconds(700)) } catch { return }
                let snapshot = game, profile = difficulty, skill = matchAdjustment
                let next = await Task.detached(priority: .userInitiated) {
                    snapshot.computerMove(difficulty: profile, adjustment: skill)
                }.value
                guard !Task.isCancelled, !leavingGame, !replaying, !gameHelp, !gameSettings, customizing == nil, !resultPresented, resolution == nil, scenePhase == .active, MountainPlatform.isActive, game.moves == snapshot.moves, computers[game.turn] else { return }
                if let next { move(next, computer: true) }
            }
            .onChange(of: game.isOver) { _, over in if over { recordWin(); pendingResult = true; presentPendingResult() } }
            .onChange(of: computers) { if computers.contains(false) { computerStarted = true }; rolesChanged = true; MountainExperience.defaults.set(computers[0], forKey: "player1AI"); MountainExperience.defaults.set(computers[1], forKey: "player2AI"); persist() }
            .onChange(of: adaptiveDifficulty) { learning = nil; persist() }
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
            .onChange(of: replaying) { _, opened in if opened { resolution = nil } else { presentPendingResult() } }
            .sheet(isPresented: $gameSettings) { MountainSettings().mountainSheetSize() }
            .onChange(of: gameSettings) { _, opened in if opened { resolution = nil; feedback.removeAll() } else { presentPendingResult() }; publishDisplay() }
            .sheet(isPresented: $gameHelp) { MountainRules { gameHelp = false }.mountainSheetSize() }
            .onChange(of: gameHelp) { _, opened in if opened { resolution = nil; feedback.removeAll() } else { presentPendingResult() }; publishDisplay() }
            .sheet(isPresented: $sharing) { MountainFinishShare(game: game, names: [playerName(0), playerName(1)], history: history) }
            .sheet(isPresented: $replaying) {
                if let replay = lastComputerMove { MountainReplayView(replay: replay).mountainSheetSize() }
            }
        .foregroundStyle(MountainStyle.cream).tint(MountainStyle.gold).preferredColorScheme(.dark)
        .mountainGameFeedback(moves: game.moves, over: humanVictory, enabled: hapticsEnabled, intensity: 0.2 + moveIntensity * 0.8)
        .offeringMountainDisplay()
#if os(macOS)
        .focusedSceneValue(\.mountainActions, MountainActions(newGame: { restart() }, options: { gameSettings = true }, rules: { gameHelp = true }, replay: lastComputerMove == nil ? nil : { replaying = true }, close: { leaveGame() }))
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

            board(width: width, maxHeight: maxHeight)
            matchControls
        }
    }
    private var startComputerButton: some View {
        Button { computerStarted = true } label: {
            Image(systemName: "play.fill").frame(width: MountainStyle.headerControlSize, height: MountainStyle.headerControlSize)
                .foregroundStyle(MountainStyle.ink).background(MountainStyle.gold, in: Circle())
        }.buttonStyle(.plain).opacity(waitingForStart ? 1 : 0).disabled(!waitingForStart).accessibilityHidden(!waitingForStart)
            .accessibilityLabel("Start computers").accessibilityIdentifier("start-computer")
    }
    private var matchControls: some View {
        HStack(spacing: 24) {
            Button { replaying = true } label: { Image(systemName: "play.rectangle").frame(width: 48, height: 48) }
                .buttonStyle(.plain).disabled(lastComputerMove == nil).opacity(lastComputerMove == nil ? 0.4 : 1)
                .accessibilityLabel("Replay computer move").accessibilityIdentifier("replay-computer").keyboardShortcut("r", modifiers: .command)
            Button { pendingResult = false; resultPresented = true } label: { Image(systemName: "flag.checkered").frame(width: 48, height: 48) }
                .buttonStyle(.plain).disabled(!game.isOver).opacity(game.isOver ? 1 : 0.4)
                .accessibilityLabel("Results").accessibilityIdentifier("game-results")
        }.font(.title2).frame(maxWidth: .infinity)
    }
    private func presentPendingResult() {
        guard pendingResult, game.isOver, resolution == nil, scenePhase == .active,
              !leavingGame, !replaying, !gameHelp, !gameSettings, customizing == nil else { return }
        pendingResult = false; resultPresented = true
    }
    private func leaveGame() { leavingGame = true; resolution = nil; feedback.removeAll(); persist(); if let onLeave { onLeave() } else { dismiss() } }
    private var waitingForStart: Bool { game.moves == 0 && computers[game.turn] && !computerStarted }
    private func playerName(_ index: Int) -> String { computers[index] ? difficulty.displayName : MountainHumanProfile.read(identity: names[index], data: humanProfiles).displayName }
    private var header: some View {
        HStack {
            Button { leaveGame() } label: {
                Image(systemName: "xmark").frame(width: MountainStyle.headerControlSize, height: MountainStyle.headerControlSize)
                    .background(MountainStyle.cream.opacity(0.1), in: Circle())
            }.accessibilityLabel("Close game").accessibilityIdentifier("close-game")
                .keyboardShortcut(.cancelAction)
                .mountainHover()
            Spacer()
            startComputerButton
            Spacer()
            Button { gameHelp = true } label: {
                Image(systemName: "questionmark").frame(width: MountainStyle.headerControlSize, height: MountainStyle.headerControlSize)
                    .background(MountainStyle.cream.opacity(0.1), in: Circle())
            }.accessibilityLabel("How to play").accessibilityIdentifier("game-help")
            Spacer()
            Button { gameSettings = true } label: {
                Image(systemName: "gearshape.fill").frame(width: MountainStyle.headerControlSize, height: MountainStyle.headerControlSize)
                    .background(MountainStyle.cream.opacity(0.1), in: Circle())
            }.accessibilityLabel("Settings").accessibilityIdentifier("play-settings").mountainHover()
        }.buttonStyle(.plain)
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
    private func score(player: Int) -> some View {
        Button { customizing = MountainHumanSelection(id: player) } label: { scoreContents(player: player) }
            .buttonStyle(.plain).accessibilityIdentifier("player-profile-\(player)")
            .accessibilityLabel(scoreDescription(player) + " Customize player")
    }
    private func scoreContents(player: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                let profile = MountainHumanProfile.read(identity: names[player], data: humanProfiles)
                if computers[player] && profile.resolvedStyle != "photo" && profile.resolvedStyle != "symbol" {
                    OpponentPortrait(difficulty: difficulty, size: 48, thinking: game.turn == player && !game.isOver && !waitingForStart && !replaying && !leavingGame, reaction: lastComputerMove?.after.moves ?? 0)
                } else {
                    MountainAvatar(name: computers[player] ? difficulty.name : profile.displayName, symbol: profile.symbol, style: profile.resolvedStyle, photoID: profile.photoID)
                }
                VStack(alignment: .leading, spacing: 3) {
                    MountainReservedText(lines: 2) { Text(playerName(player)) }.font(.subheadline.weight(.semibold))
                }
            }
            MountainReservedText {
                MountainScoreNumber(value: Double(game.scores[player])).font(MountainStyle.display(40))
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: game.scores[player])
                .accessibilityLabel("\(game.scores[player])")
                .anchorPreference(key: MountainMoveAnchors.self, value: .bounds) { [.score(player): $0] }
            }.font(MountainStyle.display(40))
        }.frame(maxWidth: .infinity, alignment: .leading).padding(18)
            .foregroundStyle(MountainStyle.player(player))
            .background(MountainStyle.player(player).opacity(game.turn == player && !game.isOver ? 0.17 : 0.06), in: RoundedRectangle(cornerRadius: 16))
            .overlay { MountainPlayerHighlight(player: player, active: game.turn == player && !game.isOver) }
            .accessibilityElement(children: .ignore).accessibilityLabel(scoreDescription(player))
    }
    private func scoreDescription(_ player: Int) -> String {
        "\(playerName(player)), \(game.scores[player]) points. \(player == 0 ? "Row" : "Column") player. \(game.isOver ? result : game.turn == player ? computers[player] ? "Computer choosing" : "Your turn" : "Waiting")."
    }
    private func move(_ id: Int, computer: Bool = false) {
        guard resolution == nil, game.canPlay(id), computers[game.turn] == computer else { return }
        let event = MountainMoveFeedback(id: game.moves + 1, tile: id, player: game.turn, points: game.tiles[id].value, maximum: game.size * game.size)
        moveIntensity = event.intensity
        if !reduceMotion { feedback = event.adding(to: feedback) }
        if computer { resolution = UUID() }
        _ = history?.record(id, before: game)
        if computer { lastComputerMove = MountainReplay(before: game, tileID: id, difficulty: difficulty) }
        lastPoints = game.tiles[id].value
        lastMove = id
        // Model mutation never animates the page layout. Cell, score and flight own their effects.
        _ = game.play(id)
        if game.isOver { recordWin() }
        persist()
    }
    private func publishDisplay() {
#if os(iOS)
        displayHub.publish(MountainDisplaySnapshot(owner: savedID, game: game,
            names: [playerName(0), playerName(1)],
            symbols: [0, 1].map { MountainHumanProfile.read(identity: names[$0], data: humanProfiles).symbol },
            computers: computers, difficulty: difficulty, lastMove: lastMove, lastPoints: lastPoints,
            paused: scenePhase != .active || replaying || leavingGame || customizing != nil || gameHelp || gameSettings,
            avatarStyles: [0, 1].map { MountainHumanProfile.read(identity: names[$0], data: humanProfiles).resolvedStyle },
            photoIDs: [0, 1].map { MountainHumanProfile.read(identity: names[$0], data: humanProfiles).photoID }))
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
    @AppStorage("aiUsesPictures", store: MountainExperience.defaults) private var pictures = false

    var body: some View {
        Group {
            if pictures { Image(difficulty.portrait).resizable().scaledToFill() }
            else { MountainAvatar(name: difficulty.name, size: size) }
        }
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
                                Text("\(replay.difficulty.displayName)'s move").font(MountainStyle.display(28))
                            }
                        }
                        Text(stage == 0 ? "Before the move" : stage == 1 ? "Choosing \(replay.before.tiles[replay.tileID].value) points" : "\(replay.difficulty.displayName) takes \(replay.before.tiles[replay.tileID].value) points")
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
    @Binding var computer: Bool
    @Binding var difficulty: ComputerDifficulty
    @Binding var adaptive: Bool
    let canResetLearning: Bool
    var onResetLearning: () -> Void
    var onDifficultyChanged: () -> Void
    @State private var name = ""
    @State private var symbol = "person.fill"
    @State private var style = "fonster"
    @State private var photoID: String?
    @State private var computerChoice = false
    @State private var difficultyChoice = ComputerDifficulty.level1
    @State private var adaptiveChoice = true
    @State private var photoData: Data?
    @State private var failure: String?
    @State private var loading = false
    @State private var loadingToken: UUID?
    @State private var resetLearning = false
#if canImport(PhotosUI)
    @State private var photoItem: PhotosPickerItem?
#endif
    @Environment(\.dismiss) private var dismiss
    private let labels = ["Person", "Paw print", "Leaf", "Sun", "Mountain", "Sparkles"]
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Spacer()
                        if let photoData, let source = CGImageSourceCreateWithData(photoData as CFData, nil), let image = CGImageSourceCreateImageAtIndex(source, 0, nil), style == "photo" {
                            Image(decorative: image, scale: 1).resizable().scaledToFill().frame(width: 96, height: 96).clipShape(Circle()).accessibilityHidden(true)
                        } else if computerChoice && style == "fonster" {
                            OpponentPortrait(difficulty: difficultyChoice, size: 96)
                        } else {
                            MountainAvatar(name: computerChoice ? difficultyChoice.name : name, symbol: symbol, style: style, photoID: photoID, size: 96)
                        }
                        Spacer()
                    }
                    if !computerChoice { TextField("Display name", text: $name).textFieldStyle(.roundedBorder).accessibilityIdentifier("profile-display-name") }
                    Toggle("Computer player", isOn: $computerChoice).accessibilityIdentifier("player-computer-toggle")
                    if computerChoice {
                        Picker("Opponent", selection: $difficultyChoice) {
                            ForEach(ComputerDifficulty.allCases) { Text($0.displayName).tag($0) }
                        }.accessibilityIdentifier("player-computer-level")
                        HStack {
                            Toggle("Adapt between games", isOn: $adaptiveChoice).accessibilityIdentifier("adaptive-difficulty")
                            MountainInfoButton(title: "Adaptive difficulty", explanation: "Starts easy, then slowly gets harder after sustained wins and recovers faster after losses. Learning is separate for each named human, board size and role. Manually changing the opponent applies to this game.")
                        }
                    }
                    HStack {
                        Button("Reset learning") { resetLearning = true }.frame(minHeight: 44).disabled(!canResetLearning).accessibilityIdentifier("reset-learning")
                        Spacer()
                        MountainInfoButton(title: "Reset learning", explanation: "Restarts learning for the current human, board size and role. A game already in progress keeps its opponent level.")
                    }
                    Button { style = "fonster" } label: { Label("Name-based avatar", systemImage: "sparkles").frame(maxWidth: .infinity, minHeight: 44) }
                        .buttonStyle(MountainButton(prominent: style == "fonster")).accessibilityIdentifier("profile-generated-avatar")
#if canImport(PhotosUI)
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label("Photo or saved Memoji", systemImage: "photo").frame(maxWidth: .infinity, minHeight: 44)
                    }.buttonStyle(MountainButton()).accessibilityIdentifier("profile-photo")
                        .task(id: photoItem) {
                            guard let photoItem else { return }
                            let token = UUID(); loadingToken = token; loading = true
                            defer { if loadingToken == token { loading = false } }
                            do {
                                guard let data = try await photoItem.loadTransferable(type: Data.self) else { throw CocoaError(.fileReadCorruptFile) }
                                let prepared = await Task.detached(priority: .userInitiated) { MountainAvatarPhotos.prepare(data) }.value
                                guard !Task.isCancelled, loadingToken == token else { return }
                                guard let prepared else { throw CocoaError(.fileReadCorruptFile) }
                                photoData = prepared; style = "photo"
                            } catch { if !Task.isCancelled { failure = "That image couldn't be opened. Try another photo." } }
                        }
#endif
                    if loading { ProgressView().accessibilityLabel("Preparing photo") }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 16) {
                        ForEach(MountainHumanProfile.symbols, id: \.self) { choice in
                            Button { symbol = choice; style = "symbol" } label: {
                                Image(systemName: choice).font(.title2).frame(width: 60, height: 60)
                                    .background(style == "symbol" && symbol == choice ? MountainStyle.gold : MountainStyle.cream.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                                    .foregroundStyle(style == "symbol" && symbol == choice ? MountainStyle.ink : MountainStyle.cream)
                            }.buttonStyle(.plain).accessibilityLabel(labels[MountainHumanProfile.symbols.firstIndex(of: choice)!])
                                .accessibilityAddTraits(style == "symbol" && symbol == choice ? .isSelected : [])
                        }
                    }
                    if let failure { Text(failure).font(.callout).foregroundStyle(MountainStyle.gold) }
                }.padding(24).frame(maxWidth: 620).frame(maxWidth: .infinity)
            }.background(MountainStyle.ink).navigationTitle("Player").mountainInlineTitle()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(loading).accessibilityIdentifier("save-profile") }
                }
        }.foregroundStyle(MountainStyle.cream).tint(MountainStyle.gold).preferredColorScheme(.dark)
            .confirmationDialog("Reset learning?", isPresented: $resetLearning, titleVisibility: .visible) { Button("Reset learning", role: .destructive) { onResetLearning() } }
            .onAppear {
                let profile = MountainHumanProfile.read(identity: identity, data: profiles)
                name = profile.displayName; symbol = profile.symbol; style = profile.resolvedStyle; photoID = profile.photoID
                computerChoice = computer; difficultyChoice = difficulty; adaptiveChoice = adaptive
            }
    }
    private func save() {
        do {
            let selectedID = style == "photo" ? try photoData.map { try MountainAvatarPhotos.save($0) } ?? photoID : nil
            guard let data = MountainHumanProfile.updating(identity: identity, displayName: name, symbol: symbol, data: profiles, avatarStyle: style, photoID: selectedID) else { throw CocoaError(.fileWriteUnknown) }
            let changedDifficulty = difficulty != difficultyChoice
            if !adaptiveChoice { MountainExperience.defaults.set(difficultyChoice.rawValue, forKey: "computerLevel") }
            profiles = data; difficulty = difficultyChoice; adaptive = adaptiveChoice; computer = computerChoice
            if changedDifficulty { onDifficultyChanged() }
            dismiss()
        } catch { failure = "Your profile couldn't be saved. Try again." }
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

private struct MountainSettings: View {
    @AppStorage("aiUsesPictures", store: MountainExperience.defaults) private var pictures = false
    @AppStorage("complexity", store: MountainExperience.defaults) private var size = 6
    @AppStorage("boardScrollThreshold", store: MountainExperience.defaults) private var threshold = 7
    @AppStorage("showStatusBar", store: MountainExperience.defaults) private var statusBar = false
    @AppStorage("animationsEnabled", store: MountainExperience.defaults) private var animations = true
    @AppStorage("hapticsEnabled", store: MountainExperience.defaults) private var haptics = true
    @AppStorage("computerMoveDuration", store: MountainExperience.defaults) private var duration = 0.7
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    withHelp("Player images", text: "Name-based Fonsters are the default. Pictures uses the existing portraits for computer players. Tap either player in a game to choose a personal photo or saved Memoji image.") {
                        Picker("Player images", selection: $pictures) { Text("Avatars").tag(false); Text("Pictures").tag(true) }
                            .accessibilityIdentifier("avatar-style-setting")
                    }
#if os(iOS)
                    Toggle("Show status bar", isOn: $statusBar).accessibilityIdentifier("show-status-bar")
#endif
                }
                Section("Board") {
                    withHelp("Board size", text: "Applies to the next game. Current games keep their board.") {
                        Stepper("Board size · \(size) × \(size)", value: $size, in: 4...14).accessibilityIdentifier("board-size-setting")
                    }
                    withHelp("Compact limit", text: "Compact boards up to this size fit the screen. Larger boards scroll horizontally. A higher limit makes tiles smaller. Roomier layouts fit the full board.") {
                        Stepper("Compact limit · \(threshold) × \(threshold)", value: $threshold, in: 4...14).accessibilityIdentifier("board-scroll-threshold")
                    }
                }
                Section("Game feedback") {
                    Toggle("Haptics", isOn: $haptics).accessibilityIdentifier("haptics-setting")
                    withHelp("Reduced motion", text: "Shows static score and turn changes instead of movement. Your device’s Reduce Motion setting is always respected.") {
                        Toggle("Reduced motion", isOn: Binding(get: { !animations }, set: { animations = !$0 })).accessibilityIdentifier("reduced-motion-setting")
                    }
                    withHelp("Animation duration", text: "Sets the pace of point flights and computer-move animations.") {
                        Picker("Animation duration", selection: $duration) {
                            Text("Fast").tag(0.4); Text("Natural").tag(0.7); Text("Relaxed").tag(1.2)
                        }.accessibilityIdentifier("computer-speed-setting")
                    }
                }
            }.scrollContentBackground(.hidden).background(MountainStyle.ink)
                .navigationTitle("Settings").mountainInlineTitle()
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }.tint(MountainStyle.gold).foregroundStyle(MountainStyle.cream).preferredColorScheme(.dark)
    }
    private func withHelp<Content: View>(_ title: String, text: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            content()
            MountainInfoButton(title: title, explanation: text)
        }
    }
}
private struct MountainInfoButton: View {
    let title: String
    let explanation: String
    @State private var showing = false
    var body: some View {
        Button { showing = true } label: { Image(systemName: "questionmark.circle").frame(width: 44, height: 44) }
            .buttonStyle(.plain).accessibilityLabel("About \(title)")
            .popover(isPresented: $showing) {
                ScrollView { VStack(alignment: .leading, spacing: 16) {
                    Text(title).font(.headline)
                    Text(explanation).font(.body).fixedSize(horizontal: false, vertical: true)
                    Button("Done") { showing = false }.frame(minHeight: 44)
                }.padding(24) }.frame(idealWidth: 320, maxWidth: 400, idealHeight: 300, maxHeight: 600)
                    .foregroundStyle(MountainStyle.cream).presentationBackground(MountainStyle.ink)
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
                        .background {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(tile.value == 0 ? MountainStyle.cream.opacity(0.08) : game.canPlay(tile.id) ? MountainStyle.player(game.turn) : MountainStyle.cream)
                                .overlay { MountainTileValueShading(value: tile.value, playable: game.canPlay(tile.id), player: game.turn, cornerRadius: 5) }
                        }
                        .overlay { RoundedRectangle(cornerRadius: 5).strokeBorder(selected == tile.id ? MountainStyle.gold : .clear, lineWidth: 2) }
                }
            }.frame(width: 448)
            Text("Classic · \(game.size) × \(game.size)\napps.apple.com/app/id971329310").font(.system(size: 11)).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }.padding(24).frame(width: 512, height: 760).background(MountainStyle.ink).foregroundStyle(MountainStyle.cream)
    }
}
