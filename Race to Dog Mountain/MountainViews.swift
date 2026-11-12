import SwiftUI
import Observation
import ImageIO
import UniformTypeIdentifiers
import UserNotifications
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
    @Environment(\.accessibilityReduceMotion) private var homeReduceMotion
    @AppStorage("animationsEnabled", store: MountainExperience.defaults) private var homeAnimations = true
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
    @AppStorage("hasPlayed", store: MountainExperience.defaults) private var hasPlayed = false
    @State private var titleGrow = 0.0
    @State private var titlePokes: [MountainVinePoke] = []
    @State private var titleSize = CGSize.zero
    @State private var launching = true

    var body: some View {
        Group {
#if os(macOS) || os(visionOS)
            if playing {
                localGame
            } else {
#if os(macOS)
                home.focusedSceneValue(\.mountainActions, MountainActions(newGame: { startLocal() }, options: { options = true }, rules: { rules = true }, history: { social = true }, invite: { friends.invite(size: size) }))
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
        .overlay { if launching { MountainVineSweep(curtain: true, duration: 1.8) { launching = false }.ignoresSafeArea() } }
        .onAppear {
            size = min(max(size, 4), 14); refreshHistory(); MountainBoardDeck.refill()
#if DEBUG
            // iPhone Duo resizes the launch scene a moment after it appears, which drops state set
            // immediately; stage the scene once it has settled.
            if let scene = MountainShowcase.scene { DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { stage(scene) } }
#endif
        }
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
            let wide = geometry.size.width > 600
            ZStack {
                MountainScenery(active: !playing && !options && !rules, followsLocalTime: true, lush: true)
                    .overlay(MountainStyle.ink.opacity(0.45))
                VStack(spacing: 12) {
                    // Holds the title's place; the vines that write it are drawn full screen below.
                    let playSize = wide ? min(200, geometry.size.height * 0.2) : 168
                    // The title takes the room left after Play and the buttons, so nothing is ever pushed off screen.
                    let titleWidth: CGFloat = wide ? min(560, geometry.size.width * 0.5) : 300
                    Color.clear.frame(maxWidth: titleWidth, maxHeight: titleWidth * MountainVineTitle.aspect)
                        .aspectRatio(1 / MountainVineTitle.aspect, contentMode: .fit)
                        .layoutPriority(1)
                        .background { GeometryReader { proxy in Color.clear.onAppear { titleSize = proxy.size }.onChange(of: proxy.size) { titleSize = proxy.size } } }
                        .anchorPreference(key: MountainTitleAnchor.self, value: .bounds) { $0 }
                        .contentShape(Rectangle())
                        .onTapGesture(coordinateSpace: .local) { point in pokeTitle(at: point, width: titleSize.width) }
                        .accessibilityElement().accessibilityLabel(Text(verbatim: "Tally Tangle")).accessibilityAddTraits(.isHeader)
                    // Leaves spill past the letters and Play's glow ring breathes outward, so keep a clear gap.
                    Spacer(minLength: 44)
                    MountainPlayButton(size: playSize) { firstPlay() }
                        .accessibilityIdentifier("start-game")
                        .keyboardShortcut("n", modifiers: .command)
                    Spacer(minLength: 16)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: typeSize.isAccessibilitySize ? 2 : 4), spacing: 10) {
                        // Game Center carries each turn between friends over the internet.
                        homeControl("Invite", symbol: "person.badge.plus", identifier: "home-invite-friend") { friends.invite(size: size) }
                            .disabled(friends.sending).accessibilityHint("Pick a Game Center friend. You take turns online.")
                        homeControl("History", symbol: "clock.arrow.circlepath", identifier: "friends-and-games") { social = true }
                        homeControl("Help", symbol: "questionmark.circle", identifier: "help") { rules = true }
                        homeControl("Settings", symbol: "gearshape.fill", identifier: "game-options") { options = true }
                    }
                }
                .padding(.horizontal, 24).padding(.top, 36).padding(.bottom, 24)
                .frame(maxWidth: 620).frame(maxWidth: .infinity)
            }
            .overlayPreferenceValue(MountainTitleAnchor.self) { anchor in
                GeometryReader { proxy in
                    if let anchor { MountainVineTitle(grow: titleGrow, frame: proxy[anchor], active: !playing && !options && !rules, pokes: titlePokes) }
                }
#if !os(visionOS)
                // Reach the very top edge on phones; visionOS windows have no edge to grow from.
                .ignoresSafeArea()
#endif
            }
            .modifier(MountainTouchBlooms(enabled: !homeReduceMotion && homeAnimations))
            .task(id: [playing, launching]) {
#if DEBUG
                if MountainShowcase.scene?.titleGrow != nil { return }
#endif
                // The vine title writes itself after the launch curtain, unwinds when a game opens,
                // and grows back when you return home.
                let still = homeReduceMotion || !homeAnimations
                if playing { withAnimation(still ? nil : .easeIn(duration: 0.5)) { titleGrow = 0 }; return }
                guard !launching, titleGrow < 1 else { return }
                if still { titleGrow = 1; return }
                titleGrow = 0
                do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
                withAnimation(.easeInOut(duration: 4.2)) { titleGrow = 1 }
            }
        }
    }

    private func pokeTitle(at point: CGPoint, width: CGFloat) {
        guard !homeReduceMotion, homeAnimations, titleGrow > 0.9 else { return }
        let size = CGSize(width: width, height: width * MountainVineTitle.aspect)
        let poke = MountainVinePoke(part: MountainVineTitle.part(at: point, in: size), point: point)
        titlePokes = Array((titlePokes + [poke]).suffix(5))
        Task { try? await Task.sleep(for: .seconds(1.6)); titlePokes.removeAll { $0.id == poke.id } }
    }

    private func homeControl(_ title: LocalizedStringResource, symbol: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: symbol).font(.title2.weight(.semibold))
                Text(title).font(.caption.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 68)
            .background(MountainStyle.ink.opacity(0.7), in: RoundedRectangle(cornerRadius: 18))
            .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(MountainStyle.cream.opacity(0.18), lineWidth: 1) }
            .contentShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(MountainPressStyle()).mountainHover()
        .accessibilityIdentifier(identifier).help(Text(title))
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
            }.background(MountainStyle.ink).navigationTitle("History").mountainInlineTitle()
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
                    MountainMatchRow(title: race.title, subtitle: race.problem != nil ? String(localized: "Refresh needed") : race.ended ? String(localized: "Finished") : race.yourTurn ? String(localized: "Your move") : String(localized: "Waiting for a friend"), scores: race.challenge?.game.scores, symbol: "person.2.fill", needsMove: race.yourTurn && race.problem == nil) { Task { await friends.open(race.id) } }
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
                Text(gameCategory == .messages ? "Your iMessage games live in their conversations. Open a conversation, tap +, then choose Tally Tangle." : gameCategory == .ai ? "Play a computer on this device. Tap its player card to choose a level." : "Share this device with a friend and take turns on the same board.")
                    .font(.body).multilineTextAlignment(.center).frame(maxWidth: .infinity)
            }
            Button { startCategoryGame() } label: { Label(gameCategory == .messages ? String(localized: "Open Messages") : String(localized: "New \(gameCategory.title) game"), systemImage: gameCategory == .messages ? "message.fill" : "play.fill").frame(maxWidth: .infinity) }
                .buttonStyle(MountainButton(prominent: true)).accessibilityIdentifier("new-category-game")
            ForEach(categoryGames.filter { !$0.game.isOver }) { saved in savedRow(saved) }
            if categoryGames.contains(where: { $0.game.isOver }) {
                Text("Finished").font(.footnote.weight(.bold)).textCase(.uppercase).tracking(1)
                    .foregroundStyle(MountainStyle.cream.opacity(0.65)).padding(.top, 8).accessibilityAddTraits(.isHeader)
                ForEach(categoryGames.filter { $0.game.isOver }) { saved in savedRow(saved) }
            }
            if let error = library.error { Text(error).font(.footnote).foregroundStyle(MountainStyle.gold) }
        }
    }
    private func savedRow(_ saved: SavedMountainGame) -> some View {
        MountainMatchRow(title: saved.names.enumerated().map { saved.computers[$0.offset] ? saved.rival($0.offset).displayName : MountainHumanProfile.read(identity: $0.element, data: humanProfiles).displayName }.joined(separator: " & "),
                         subtitle: saved.game.isOver ? String(localized: "Finished · \(saved.game.size) × \(saved.game.size)") : "\(saved.game.size) × \(saved.game.size)", scores: saved.game.scores,
                         symbol: saved.computers.contains(true) ? "sparkles" : "person.2.fill", needsMove: !saved.game.isOver,
                         history: saved.game.isOver ? saved.history : nil) { resume(saved) }
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
        if computers == [true, true] { next.firstDifficulty = MountainGameView.storedFirstDifficulty }
        library.save(next); selection = next; playing = true
    }
    /// A first-time player gets the short guide and a 6 × 6 board before their first race.
    private func firstPlay() {
        guard !hasPlayed else { startLocal(); return }
        hasPlayed = true; size = 6; rules = true
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
    private var names: [String] { [clean(firstName, fallback: String(localized: "Player 1")), clean(secondName, fallback: String(localized: "Player 2"))] }
    private func clean(_ name: String, fallback: String) -> String {
        let result = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? fallback : String(result.prefix(60))
    }
    private func refreshHistory() {
        history = [0, 1].map { MountainExperience.defaults.integer(forKey: "\(names[$0])vvv\(names[1 - $0])") }
    }
    private var playerOptions: some View { MountainSettings() }
#if DEBUG
    /// Marketing capture: puts the home screen into one prepared scene.
    private func stage(_ scene: MountainShowcase.Scene) {
        launching = false
        for saved in scene.library { library.save(saved) }
        if let grow = scene.titleGrow { titleGrow = grow }
        switch scene.home {
        case .title: break
        case .settings: options = true
        case .help: rules = true
        case .history(let category): gameCategory = category; social = true
        }
        if let game = scene.game {
            library.save(game)
            selection = game; playing = true
        }
#if os(macOS)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            for window in NSApplication.shared.windows where window.isVisible && window.styleMask.contains(.titled) {
                window.setContentSize(NSSize(width: 1280, height: 800)); window.center()
            }
        }
#endif
    }
#endif
}


private struct MountainRules: View {
    var onPlay: () -> Void
    @State private var lesson: MountainTutorial = {
        var lesson = MountainTutorial()
#if DEBUG
        // Marketing capture can open the guide partway through.
        for _ in 0..<(MountainShowcase.scene?.tutorialSteps ?? 0) { lesson.choose(lesson.game.legalMoves[lesson.game.legalMoves.count / 2]) }
#endif
        return lesson
    }()
    @State private var feedback: [MountainMoveFeedback] = []
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("animationsEnabled", store: MountainExperience.defaults) private var animationsEnabled = true
    private let titles = [String(localized: "Follow the gold row"), String(localized: "Now try the mint column"), String(localized: "Think one move ahead"), String(localized: "Leave a good path"), String(localized: "Ready to tangle")]
    private let details = [String(localized: "Tap a gold number. It adds to your score."), String(localized: "Your choice set this column. Tap a mint number."), String(localized: "Pick a gold number. Notice which column you leave."), String(localized: "Take a mint number. Used tiles stay empty."), String(localized: "When the next player has no moves, the higher score wins.")]
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
            Text(player == 0 ? String(localized: "You") : String(localized: "Friend")).font(.subheadline.bold())
            Spacer(minLength: 4)
            MountainReservedText { MountainScoreNumber(value: Double(lesson.game.scores[player])) }
                .font(.title2.bold()).frame(width: 48)
                .anchorPreference(key: MountainMoveAnchors.self, value: .bounds) { [.score(player): $0] }
        }.padding(12).foregroundStyle(MountainStyle.player(player))
            .background(MountainStyle.player(player).opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
            .overlay { MountainPlayerHighlight(player: player, active: lesson.game.turn == player && !lesson.finished) }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(player == 0 ? String(localized: "You, \(lesson.game.scores[player]) points. Row player.") : String(localized: "Friend, \(lesson.game.scores[player]) points. Column player."))
    }
}

private struct MountainGameView: View {
    @State private var names: [String]
    @AppStorage("player1Color", store: MountainExperience.defaults) private var firstColor = 0
    @AppStorage("player2Color", store: MountainExperience.defaults) private var secondColor = 1
    @State private var swapping = false
    @State private var switchingSeats = false
    @State private var seatVines = 0
    /// Keyboard choice on the active line: arrow keys move it, Return or Space plays it.
    @State private var keyboardPick: Int?
    @FocusState private var keyboardFocus: Bool
    @State private var vines = 0
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
    /// Player 1's own rival when the computer plays itself.
    @State private var firstDifficulty: ComputerDifficulty
    static var storedFirstDifficulty: ComputerDifficulty {
        let defaults = MountainExperience.defaults
        return ComputerDifficulty(rawValue: defaults.object(forKey: "firstComputerLevel") as? Int ?? defaults.object(forKey: "computerLevel") as? Int ?? 5) ?? .level6
    }
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
        _names = State(initialValue: saved?.names ?? names)
        self.onLeave = onLeave; self.onSave = onSave
        self.learningStore = learningStore
        _difficulty = State(initialValue: saved?.difficulty ?? difficulty)
        _firstDifficulty = State(initialValue: saved?.firstDifficulty ?? Self.storedFirstDifficulty)
        _learning = State(initialValue: saved?.learning)
        _savedID = State(initialValue: saved?.id ?? UUID())
        _recorded = State(initialValue: saved?.recorded ?? false)
        _computerStarted = State(initialValue: saved?.computerStarted ?? computers.contains(false))
        _rolesChanged = State(initialValue: saved?.rolesChanged ?? false)
        _lastComputerMove = State(initialValue: saved?.replay)
        _matchAdjustment = State(initialValue: saved?.adjustment ?? adjustment)
        // Each presentation owns a fresh game and a snapshot of player settings.
        let initial = saved?.game ?? MountainBoardDeck.next(size: size, firstPlayer: MountainGame.randomStartingPlayer(computers: computers))
        _game = State(initialValue: initial)
        _history = State(initialValue: saved == nil ? MountainHistory(initial: initial) : saved?.history)
        _computers = State(initialValue: saved?.computers ?? computers)
    }

    private var gameContent: some View {
        GeometryReader { geometry in
            ZStack {
                MountainScenery(active: !replaying && !leavingGame, celebration: humanVictory)
                MountainStyle.ink.opacity(0.60).ignoresSafeArea()
                // A finished round fits one screen; accessibility text sizes keep the scrolling layout.
                let fitted = finished && !typeSize.isAccessibilitySize
                let column = sideColumn(geometry)
                let content = VStack(spacing: fitted ? 16 : 24) {
                        if column == nil { header }
                        if fitted {
                            finishLayout(wide: usesSideControls(width: geometry.size.width, height: geometry.size.height))
                                .frame(maxHeight: .infinity)
                        } else if usesSideControls(width: geometry.size.width, height: geometry.size.height) && !typeSize.isAccessibilitySize {
                            HStack(alignment: .top, spacing: 24) {
                                VStack(spacing: 18) {
                                    if finished {
                                        finishPanel.transition(finishTransition)
                                        finishActions.transition(finishTransition)
                                    } else {
                                        scoreCards
                                        matchControls
                                    }
                                }.frame(width: finished ? 320 : 240)
                                board(width: max(160, min(min(geometry.size.width, 1268) - gameHorizontalPadding - (finished ? 344 : 264), geometry.size.height - 128)) * (finished ? 0.86 : 1), fitAllSizes: geometry.size.width >= 900 && geometry.size.height >= 600)
                                    .frame(maxWidth: .infinity)
                            }
                        } else {
                            verticalGame(width: min(geometry.size.width - 32, 760), maxHeight: geometry.size.width >= 600 && !typeSize.isAccessibilitySize ? max(160, geometry.size.height - boardTop - gameHorizontalPadding) : nil)
                        }
                    }
                    .animation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.82), value: resultPresented)
                    .coordinateSpace(name: "mountain-game-content")
                    .onPreferenceChange(MountainBoardTop.self) { boardTop = $0 }
#if os(visionOS)
                    .padding(32).frame(maxWidth: 1268)
#else
                    .padding(16)
#endif
                        .frame(maxWidth: 1268)
                        .frame(maxWidth: .infinity)
                if fitted {
                    content.frame(maxHeight: .infinity, alignment: .top).transition(.opacity)
                } else {
                    ScrollView { content }.scrollIndicators(.hidden).transition(.opacity)
                }
                if let column {
                    // Below the status bar and camera at the top of the column.
                    let height = min(380, geometry.size.height * 0.62)
                    headerBar(vertical: true).frame(width: column, height: height)
                        .position(x: geometry.size.width + column / 2, y: 76 + height / 2)
                }
            }
            .animation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.82), value: resultPresented)
            .overlayPreferenceValue(MountainMoveAnchors.self) { anchors in
                MountainMoveEffects(events: $feedback, anchors: anchors, reduceMotion: reduceMotion)
            }
            .overlay { MountainVineSweep(trigger: vines).ignoresSafeArea() }
            .modifier(MountainTouchBlooms(enabled: !reduceMotion))
            .onChange(of: geometry.size) { _, _ in feedback.removeAll() }
            .onChange(of: scenePhase) { _, phase in if phase != .active { feedback.removeAll() }; publishDisplay() }
            .onChange(of: reduceMotion) { _, reduced in if reduced { feedback.removeAll() } }
            .sheet(item: $customizing) { player in MountainHumanEditor(identity: names[player.id], seat: player.id, profiles: $humanProfiles, computer: $computers[player.id], difficulty: player.id == 0 && computers[1] ? $firstDifficulty : $difficulty, levelKey: player.id == 0 && computers[1] ? "firstComputerLevel" : "computerLevel", adaptive: $adaptiveDifficulty, canResetLearning: computers.contains(false), onResetLearning: { if let human = computers[player.id] ? computers.firstIndex(of: false) : player.id { learningStore?.reset(key: MountainLearningStore.key(name: names[human], size: game.size, seat: human)) } }, onDifficultyChanged: { rolesChanged = true; learning = nil; if player.id == 0 && computers[1] { MountainExperience.defaults.set(firstDifficulty.rawValue, forKey: "firstComputerLevel") } else { computerLevel = difficulty.rawValue }; persist() }).mountainSheetSize() }
            .onAppear {
                displayHub.claim(owner: savedID); if game.isOver { resultPresented = true }; publishDisplay(); MountainReminders.cancelUnfinished()
#if DEBUG
                if let scene = MountainShowcase.scene {
                    if let last = history?.choices.last, let initial = history?.initial { lastMove = last; lastPoints = initial.tiles[last].value }
                    switch scene.overlay {
                    case .none: break
                    case .replay: replaying = true
                    case .editor(let seat): customizing = MountainHumanSelection(id: seat)
                    case .settings: gameSettings = true
                    }
                }
#endif
            }
            .onChange(of: humanProfiles) { publishDisplay() }
            .onChange(of: feedback.isEmpty) { presentPendingResult() }
            .onChange(of: customizing?.id) { publishDisplay(); presentPendingResult() }
            .onChange(of: replaying) { publishDisplay() }
            .onChange(of: resultPresented) { publishDisplay() }

        }
    }
    var body: some View {
        gameContent
#if os(macOS)
            .focusable().focusEffectDisabled().focused($keyboardFocus)
            .onAppear { keyboardFocus = true }
            .onKeyPress(keys: [.leftArrow, .upArrow]) { _ in stepPick(-1) }
            .onKeyPress(keys: [.rightArrow, .downArrow]) { _ in stepPick(1) }
            .onKeyPress(keys: [.return, .space]) { _ in
                guard let pick = keyboardPick, game.canPlay(pick) else { return .ignored }
                move(pick); return .handled
            }
            .onChange(of: game.moves) { keyboardPick = nil }
#endif
            .onReceive(NotificationCenter.default.publisher(for: MountainPlatform.didBecomeActive)) { _ in foregroundNonce += 1 }
            .task(id: "\(savedID)-\(gameSettings)-\(gameHelp)-\(game.moves)-\(computers)-\(leavingGame)-\(foregroundNonce)-\(computerStarted)-\(replaying)-\(customizing?.id ?? -1)-\(resultPresented)-\(resolution?.uuidString ?? "ready")-\(scenePhase)") {
                guard !MountainShowcase.freezesComputer, scenePhase == .active, MountainPlatform.isActive, !leavingGame, !replaying, !gameHelp, !gameSettings, customizing == nil, !resultPresented, resolution == nil, !waitingForStart, !game.isOver, computers[game.turn] else { return }
                do { try await Task.sleep(for: .milliseconds(700)) } catch { return }
                let snapshot = game, profile = rival(game.turn), skill = matchAdjustment
                let next = await Task.detached(priority: .userInitiated) {
                    snapshot.computerMove(difficulty: profile, adjustment: skill)
                }.value
                guard !Task.isCancelled, !leavingGame, !replaying, !gameHelp, !gameSettings, customizing == nil, !resultPresented, resolution == nil, scenePhase == .active, MountainPlatform.isActive, game.moves == snapshot.moves, computers[game.turn] else { return }
                if let next { move(next, computer: true) }
            }
            .onChange(of: game.isOver) { _, over in if over { recordWin(); pendingResult = true; presentPendingResult() } }
            .onChange(of: computers) { MountainExperience.defaults.set(computers[0], forKey: "player1AI"); MountainExperience.defaults.set(computers[1], forKey: "player2AI"); if swapping { swapping = false; restart(sweep: false); return }; if computers.contains(false) { computerStarted = true }; rolesChanged = true; persist() }
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
        .mountainGameFeedback(moves: game.moves, over: humanVictory && resultPresented, enabled: hapticsEnabled, intensity: 0.2 + moveIntensity * 0.8)
        .offeringMountainDisplay()
#if os(macOS)
        .focusedSceneValue(\.mountainActions, MountainActions(newGame: { restart() }, options: { gameSettings = true }, rules: { gameHelp = true }, replay: lastComputerMove == nil ? nil : { replaying = true }, close: { leaveGame() }, swap: game.moves == 0 && !finished ? { swapSeats() } : nil))
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
        MountainBoard(game: game, availableWidth: width, availableHeight: maxHeight, fitAllSizes: fitAllSizes, interactive: !computers[game.turn] && resolution == nil, lastMove: lastMove, lastPoints: lastPoints, selected: resolution == nil ? keyboardPick : lastComputerMove?.tileID) { move($0) }
            .overlay { MountainVineSweep(trigger: seatVines, cover: true, duration: Self.seatCover).clipShape(RoundedRectangle(cornerRadius: 20)) }
            .background { GeometryReader { proxy in
                Color.clear.preference(key: MountainBoardTop.self, value: proxy.frame(in: .named("mountain-game-content")).minY)
            } }
    }
    private func verticalGame(width: CGFloat, maxHeight: CGFloat? = nil) -> some View {
        VStack(spacing: 24) {
            if finished {
                finishPanel.transition(finishTransition)
            } else if typeSize.isAccessibilitySize {
                VStack(spacing: 14) { scoreCards }
            } else {
                HStack(spacing: 14) { scoreCards }
            }
            // The finished board steps back so the result and actions share the space evenly.
            board(width: finished ? width * 0.72 : width, maxHeight: maxHeight.map { finished ? $0 * 0.6 : $0 })
                .opacity(finished ? 0.8 : 1)
            if finished { finishActions.transition(finishTransition) } else { matchControls }
        }
    }
    private var startComputerButton: some View {
        Button { computerStarted = true } label: {
            Image(systemName: "play.fill").frame(width: MountainStyle.headerControlSize, height: MountainStyle.headerControlSize)
                .foregroundStyle(MountainStyle.ink).background(MountainStyle.gold, in: Circle())
        }.buttonStyle(.plain).opacity(waitingForStart ? 1 : 0).disabled(!waitingForStart).accessibilityHidden(!waitingForStart)
            .accessibilityLabel("Start computers").accessibilityIdentifier("start-computer")
    }
    /// One clear, labelled action: watch the computer's last pick again. Space is reserved so the board never jumps.
    private var matchControls: some View {
        let replay = lastComputerMove
        return Button { replaying = true } label: {
            HStack(spacing: 10) {
                if let replay { OpponentPortrait(difficulty: replay.difficulty, size: 28) }
                Text(replay.map { String(localized: "Replay \($0.difficulty.name)’s move") } ?? String(localized: "Replay"))
                    .font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
                Image(systemName: "play.fill").font(.caption)
            }
            .padding(.horizontal, 16).frame(minHeight: 44)
            .background(MountainStyle.ink.opacity(0.85), in: Capsule())
            .overlay { Capsule().strokeBorder(MountainStyle.cream.opacity(0.35), lineWidth: 1) }
        }
        .buttonStyle(.plain).mountainHover()
        .opacity(replay == nil ? 0 : 1).disabled(replay == nil).accessibilityHidden(replay == nil)
        .accessibilityLabel("Replay computer move").accessibilityIdentifier("replay-computer").keyboardShortcut("r", modifiers: .command)
        .frame(maxWidth: .infinity)
    }
    private func presentPendingResult() {
        guard pendingResult, game.isOver, resolution == nil, scenePhase == .active,
              !leavingGame, !replaying, !gameHelp, !gameSettings, customizing == nil,
              feedback.isEmpty else { return } // Let the final points land on the score first.
        pendingResult = false; resultPresented = true
    }
    private func stepPick(_ step: Int) -> KeyPress.Result {
        let line = game.legalMoves
        guard !line.isEmpty, !computers[game.turn], resolution == nil, !finished else { return .ignored }
        let index = keyboardPick.flatMap(line.firstIndex) ?? (step > 0 ? -1 : line.count)
        keyboardPick = line[min(line.count - 1, max(0, index + step))]
        return .handled
    }
    private func leaveGame() { if game.moves > 0, !game.isOver, computers.contains(false) { MountainReminders.scheduleUnfinished() }; leavingGame = true; resolution = nil; feedback.removeAll(); persist(); if let onLeave { onLeave() } else { dismiss() } }
    /// Seats carry the row/column role, so a switch starts a fresh, balanced race. Vines cover
    /// the board, the players trade places and the new board is dealt underneath, then the vines recede.
    private func swapSeats() {
        guard game.moves == 0, !switchingSeats else { return }
        guard !reduceMotion else { performSwap(); return }
        switchingSeats = true
        seatVines += 1
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.seatCover / 2)) // The vines fully cover the board halfway through.
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { performSwap() }
            switchingSeats = false
        }
    }
    private static let seatCover = 1.8
    private func performSwap() {
        names.swapAt(0, 1)
        let defaults = MountainExperience.defaults
        defaults.set(names[0], forKey: "player1Name"); defaults.set(names[1], forKey: "player2Name")
        (firstColor, secondColor) = (secondColor, firstColor)
        if computers == [true, true] {
            (firstDifficulty, difficulty) = (difficulty, firstDifficulty)
            defaults.set(firstDifficulty.rawValue, forKey: "firstComputerLevel"); computerLevel = difficulty.rawValue
        }
        if computers[0] != computers[1] { swapping = true; computers.swapAt(0, 1) } else { restart(sweep: false) }
    }
    /// Cards are keyed by player, so after a switch each card slides to its new seat.
    private var scoreCards: some View {
        let keys = names[0] == names[1] ? ["0", "1"] : names
        return ForEach(keys, id: \.self) { key in score(player: keys.firstIndex(of: key) ?? 0) }
    }
    private var waitingForStart: Bool { game.moves == 0 && computers[game.turn] && !computerStarted }
    /// Each seat's computer rival; player 1 has its own only when the computer plays itself.
    private func rival(_ seat: Int) -> ComputerDifficulty { seat == 0 && computers[1] ? firstDifficulty : difficulty }
    /// Two copies of one rival show its two looks, painting and Fonster, so the seats stay distinct.
    private func twin(_ seat: Int) -> Bool { seat == 0 && computers == [true, true] && firstDifficulty == difficulty }
    private func playerName(_ index: Int) -> String { computers[index] ? rival(index).displayName : MountainHumanProfile.read(identity: names[index], data: humanProfiles).displayName }
    private var header: some View { headerBar(vertical: false) }
    /// A screen that reserves a whole side column (iPhone Duo's outer display keeps one for its
    /// status bar and camera) gets the controls stacked down that column, as Apple's own apps do.
    private func sideColumn(_ geometry: GeometryProxy) -> CGFloat? {
        geometry.safeAreaInsets.trailing >= 44 ? geometry.safeAreaInsets.trailing : nil
    }
    private func headerBar(vertical: Bool) -> some View {
        let layout = vertical ? AnyLayout(VStackLayout(spacing: 14)) : AnyLayout(HStackLayout())
        return layout {
            Button { leaveGame() } label: {
                Image(systemName: "xmark").frame(width: MountainStyle.headerControlSize, height: MountainStyle.headerControlSize)
                    .background(MountainStyle.cream.opacity(0.1), in: Circle())
            }.accessibilityLabel("Close game").accessibilityIdentifier("close-game")
                .keyboardShortcut(.cancelAction)
                .mountainHover()
            Spacer()
            Button { swapSeats() } label: {
                Image(systemName: "arrow.left.arrow.right").frame(width: MountainStyle.headerControlSize, height: MountainStyle.headerControlSize)
                    .background(MountainStyle.cream.opacity(0.1), in: Circle())
            }.accessibilityLabel("Switch player 1 and player 2")
                .accessibilityIdentifier("swap-players").mountainHover()
                // Only offered before the first move, so a switch never throws away a game in progress.
                .opacity(game.moves == 0 && !finished ? 1 : 0).disabled(game.moves > 0 || finished || switchingSeats)
                .accessibilityHidden(game.moves > 0 || finished)
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
    private var finished: Bool { resultPresented && game.isOver }
    private var finishTransition: AnyTransition { reduceMotion ? .opacity : .scale(scale: 0.9).combined(with: .opacity) }
    private var finishPanel: some View {
        MountainFinishPanel(result: result, names: [playerName(0), playerName(1)], scores: game.scores,
                            humanVictory: humanVictory, reduceMotion: reduceMotion, haptics: hapticsEnabled)
    }
    @ViewBuilder private func finishLayout(wide: Bool) -> some View {
        if wide {
            HStack(spacing: 24) {
                VStack(spacing: 18) { finishPanel; finishActions }.frame(width: 320)
                finishBoard
            }.transition(finishTransition)
        } else {
            VStack(spacing: 16) { finishPanel; finishBoard; finishActions }.transition(finishTransition)
        }
    }
    private var finishBoard: some View {
        MountainFinishBoard(game: game, history: history, names: [playerName(0), playerName(1)], reduceMotion: reduceMotion)
            .frame(maxWidth: 520, maxHeight: 520).frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    private var finishActions: some View {
        VStack(spacing: 12) {
            Button { restart() } label: { Label("Play again", systemImage: "arrow.clockwise").frame(maxWidth: .infinity) }
                .buttonStyle(MountainButton(prominent: true)).accessibilityIdentifier("result-rematch")
            if history?.initial != nil { sameBoardMenu }
            HStack(spacing: 12) {
                Button { sharing = true } label: { Label("Share", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }
                    .buttonStyle(MountainButton()).accessibilityIdentifier("share-result")
                Button { leaveGame() } label: { Label("Home", systemImage: "house.fill").frame(maxWidth: .infinity) }
                    .buttonStyle(MountainButton()).accessibilityIdentifier("result-home")
            }
        }.frame(maxWidth: 520)
    }
    /// Replay this exact board, with the same players or a different opponent.
    private var sameBoardMenu: some View {
        Menu {
            Button("Same players") { rematch() }
            Button("Pass & Play") { rematch(computers: [false, false]) }
            Section("Against the computer") {
                ForEach(ComputerDifficulty.allCases) { level in
                    Button(level.displayName) {
                        let human = computers.firstIndex(of: false) ?? 0
                        rematch(computers: [human != 0, human == 0], rival: level)
                    }
                }
            }
        } label: {
            Label("Rematch on this board", systemImage: "square.grid.3x3.fill").frame(maxWidth: .infinity)
        }
        .menuStyle(.button).menuIndicator(.hidden).buttonStyle(MountainButton()).accessibilityIdentifier("result-same-board")
    }
    private func rematch(computers next: [Bool]? = nil, rival: ComputerDifficulty? = nil) {
        guard let board = history?.initial else { restart(); return }
        if let next, next != computers { computers = next }
        restart(board: board)
        if let rival {
            difficulty = rival; computerLevel = rival.rawValue
            learning = nil; rolesChanged = true; persist()
        }
    }
    private var result: String {
        game.scores[0] == game.scores[1] ? String(localized: "A tie!") : String(localized: "\(playerName(game.scores[0] > game.scores[1] ? 0 : 1)) wins!")
    }
    private func score(player: Int) -> some View {
        Button { customizing = MountainHumanSelection(id: player) } label: { scoreContents(player: player) }
            .buttonStyle(.plain).accessibilityIdentifier("player-profile-\(player)")
            .accessibilityLabel(scoreDescription(player) + " " + String(localized: "Customize player"))
    }
    private func scoreContents(player: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                let profile = MountainHumanProfile.read(identity: names[player], data: humanProfiles)
                if computers[player] {
                    OpponentPortrait(difficulty: rival(player), size: 48, twin: twin(player), thinking: game.turn == player && !game.isOver && !waitingForStart && !replaying && !leavingGame, reaction: lastComputerMove?.after.moves ?? 0, activity: avatarActivity(player))
                } else {
                    MountainAvatar(name: profile.displayName, symbol: profile.symbol, style: profile.resolvedStyle, photoID: profile.photoID, activity: avatarActivity(player))
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
    private func avatarActivity(_ player: Int) -> MountainAvatarActivity {
        .init(game: game, player: player,
            paused: replaying || leavingGame || gameHelp || gameSettings || customizing != nil || scenePhase != .active,
            lastMove: lastMove)
    }
    private func scoreDescription(_ player: Int) -> String {
        MountainSpeech.player(playerName(player), points: game.scores[player], seat: player) + " " + (game.isOver ? result : game.turn == player ? computers[player] ? String(localized: "Computer choosing") : String(localized: "Your turn") : String(localized: "Waiting"))
    }
    private func move(_ id: Int, computer: Bool = false) {
        guard resolution == nil, game.canPlay(id), computers[game.turn] == computer else { return }
        let event = MountainMoveFeedback(id: game.moves + 1, tile: id, player: game.turn, points: game.tiles[id].value, maximum: game.size * game.size)
        moveIntensity = event.intensity
        if !reduceMotion { feedback = event.adding(to: feedback) }
        if computer { resolution = UUID() }
        _ = history?.record(id, before: game)
        if computer { lastComputerMove = MountainReplay(before: game, tileID: id, difficulty: rival(game.turn)) }
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
            photoIDs: [0, 1].map { MountainHumanProfile.read(identity: names[$0], data: humanProfiles).photoID },
            firstDifficulty: firstDifficulty, history: history, finished: finished))
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
        saved.firstDifficulty = computers == [true, true] ? firstDifficulty : nil
        saved.history = history
        saved.recorded = recorded; saved.computerStarted = computerStarted; saved.rolesChanged = rolesChanged
        onSave?(saved)
    }
    private func restart(sweep: Bool = true, board: MountainGame? = nil) {
        feedback.removeAll(); resultPresented = false; pendingResult = false
        savedID = UUID()
        displayHub.claim(owner: savedID)
        game = board ?? MountainBoardDeck.next(size: game.size, firstPlayer: MountainGame.randomStartingPlayer(computers: computers))
        if sweep { vines += 1 }
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
        firstDifficulty = Self.storedFirstDifficulty
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
    var twin = false
    var thinking = false
    var reaction = 0
    var activity = MountainAvatarActivity()
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage("animationsEnabled", store: MountainExperience.defaults) private var animationsEnabled = true
    private var reduceMotion: Bool { systemReduceMotion || !animationsEnabled }
    @Environment(\.scenePhase) private var scenePhase
    private var bobbing: Bool { thinking && !reduceMotion && scenePhase == .active }

    @ViewBuilder private var face: some View {
        MountainRivalFace(difficulty: difficulty, twin: twin, size: size)
    }
    private var framed: some View {
        face.frame(width: size, height: size).clipShape(Circle())
            .overlay { Circle().strokeBorder(MountainStyle.gold.opacity(0.65), lineWidth: 2) }
    }
    var body: some View {
        framed
            .phaseAnimator([false, true], trigger: reaction) { content, phase in
                let react = !reduceMotion && phase
                let scale: Double = react ? 1.06 + Double(difficulty.rawValue % 4) * 0.01 : 1
                let tilt: Double = react ? (difficulty.rawValue % 2 == 0 ? 4 : -4) : 0
                return content.scaleEffect(scale).rotationEffect(.degrees(tilt))
            } animation: { _ in reduceMotion ? nil : .spring(response: 0.3 + Double(difficulty.rawValue) * 0.015) }
            .phaseAnimator(bobbing ? [false, true] : [false]) { content, phase in
                let lift: CGFloat = phase ? -2 - CGFloat(difficulty.rawValue % 3) : 0
                return content.offset(y: lift)
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
                        Text(stage == 0 ? String(localized: "Before the move") : stage == 1 ? String(localized: "Choosing \(replay.before.tiles[replay.tileID].value) points") : String(localized: "\(replay.difficulty.displayName) takes \(replay.before.tiles[replay.tileID].value) points"))
                            .font(.title3.bold()).multilineTextAlignment(.center)
                        Text("Row player \(shown.scores[0]) · Column player \(shown.scores[1])").monospacedDigit()
                        MountainBoard(game: shown, availableWidth: min(geometry.size.width - 32, 760), lastMove: stage == 2 ? replay.tileID : nil, lastPoints: replay.before.tiles[replay.tileID].value, selected: stage > 0 ? replay.tileID : nil)
                        Text(replay.before.turn == 0 ? "Row \(replay.tileID / shown.size + 1), column \(replay.tileID % shown.size + 1). Sets the next column." : "Row \(replay.tileID / shown.size + 1), column \(replay.tileID % shown.size + 1). Sets the next row.")
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
    let seat: Int
    @Binding var profiles: Data
    @Binding var computer: Bool
    @Binding var difficulty: ComputerDifficulty
    var levelKey = "computerLevel"
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
    @State private var colorChoice = 0
    @State private var customEmoji = ""
    @FocusState private var nameFocused: Bool
#if canImport(PhotosUI)
    @State private var photoItem: PhotosPickerItem?
#endif
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Spacer()
                        if let photoData, let source = CGImageSourceCreateWithData(photoData as CFData, nil), let image = CGImageSourceCreateImageAtIndex(source, 0, nil), style == "photo" {
                            Image(decorative: image, scale: 1).resizable().scaledToFill().frame(width: 96, height: 96).clipShape(Circle()).accessibilityHidden(true)
                        } else if computerChoice {
                            OpponentPortrait(difficulty: difficultyChoice, size: 96)
                        } else {
                            MountainAvatar(name: computerChoice ? difficultyChoice.name : name, symbol: symbol, style: style, photoID: photoID, size: 96)
                        }
                        Spacer()
                    }
                    Toggle("Computer player", isOn: $computerChoice).accessibilityIdentifier("player-computer-toggle")
                        .onChange(of: computerChoice) { _, computer in if !computer { nameFocused = true } }
                    nameChoices
                    if computerChoice {
                        Picker("Opponent", selection: $difficultyChoice) {
                            ForEach(ComputerDifficulty.allCases) { Text($0.displayName).tag($0) }
                        }.accessibilityIdentifier("player-computer-level")
                        HStack {
                            Toggle("Adapt between games", isOn: $adaptiveChoice).accessibilityIdentifier("adaptive-difficulty")
                            MountainInfoButton(title: String(localized: "Adaptive difficulty"), explanation: "Starts easy, then slowly gets harder after sustained wins and recovers faster after losses. Learning is separate for each named human, board size and role. Manually changing the opponent applies to this game.")
                        }
                    }
                    HStack {
                        Button("Reset learning") { resetLearning = true }.frame(minHeight: 44).disabled(!canResetLearning).accessibilityIdentifier("reset-learning")
                        Spacer()
                        MountainInfoButton(title: String(localized: "Reset learning"), explanation: "Restarts learning for the current human, board size and role. A game already in progress keeps its opponent level.")
                    }
                    colorChoices
                    pictureChoices
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
                colorChoice = MountainStyle.colorIndex(seat)
                computerChoice = computer; difficultyChoice = difficulty; adaptiveChoice = adaptive
            }
    }
    @ViewBuilder private var nameChoices: some View {
        if !computerChoice {
            TextField("Player name", text: $name).textFieldStyle(.roundedBorder).focused($nameFocused)
                .accessibilityIdentifier("profile-display-name")
            let known = MountainHumanProfile.knownNames(data: profiles).filter { $0 != name }
            if !known.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(known, id: \.self) { choice in
                            Button(choice) { name = choice }.font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 14).frame(minHeight: 44)
                                .background(MountainStyle.cream.opacity(0.12), in: Capsule()).buttonStyle(.plain)
                                .accessibilityHint("Use this name")
                        }
                    }
                }.scrollIndicators(.hidden).accessibilityIdentifier("known-player-names")
            }
        }
    }
    @ViewBuilder private var colorChoices: some View {
        Text("Color").font(.headline)
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
            ForEach(MountainStyle.palette.indices, id: \.self) { index in
                let taken = index == MountainStyle.colorIndex(1 - seat)
                Button { colorChoice = index } label: {
                    Circle().fill(MountainStyle.swatch(index)).frame(width: 40, height: 40)
                        .overlay { if colorChoice == index { Image(systemName: "checkmark").font(.headline).foregroundStyle(MountainStyle.ink) } }
                        .overlay { Circle().strokeBorder(colorChoice == index ? MountainStyle.cream : .clear, lineWidth: 3) }
                        .opacity(taken ? 0.25 : 1).frame(width: 44, height: 44)
                }.buttonStyle(.plain).disabled(taken)
                    .accessibilityLabel(taken ? String(localized: "\(MountainStyle.palette[index].name), used by the other player") : MountainStyle.palette[index].name)
                    .accessibilityAddTraits(colorChoice == index ? .isSelected : [])
            }
        }.accessibilityIdentifier("player-colors")
    }
    @ViewBuilder private var pictureChoices: some View {
        if !computerChoice {
        Text("Picture").font(.headline)
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
                } catch { if !Task.isCancelled { failure = String(localized: "That image couldn't be opened. Try another photo.") } }
            }
#endif
        if loading { ProgressView().accessibilityLabel("Preparing photo") }
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 16) {
            ForEach(MountainHumanProfile.symbols, id: \.self) { choice in
                Button { symbol = choice; style = "symbol" } label: {
                    Image(systemName: choice).font(.title2).frame(width: 60, height: 60)
                        .background(style == "symbol" && symbol == choice ? MountainStyle.gold : MountainStyle.cream.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(style == "symbol" && symbol == choice ? MountainStyle.ink : MountainStyle.cream)
                }.buttonStyle(.plain).accessibilityLabel(MountainHumanProfile.label(symbol: choice))
                    .accessibilityAddTraits(style == "symbol" && symbol == choice ? .isSelected : [])
            }
        }
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 52))], spacing: 12) {
            ForEach(MountainHumanProfile.emoji, id: \.self) { choice in
                Button { symbol = choice; style = "emoji" } label: {
                    Text(choice).font(.title).frame(width: 52, height: 52)
                        .background(style == "emoji" && symbol == choice ? MountainStyle.gold : MountainStyle.cream.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain).accessibilityAddTraits(style == "emoji" && symbol == choice ? .isSelected : [])
            }
        }.accessibilityIdentifier("player-emoji")
        TextField("Or type any emoji", text: $customEmoji).textFieldStyle(.roundedBorder)
            .accessibilityIdentifier("custom-emoji")
            .onChange(of: customEmoji) { _, typed in
                guard let last = typed.last.map(String.init), MountainHumanProfile.isEmoji(last) else { return }
                symbol = last; style = "emoji"
            }
        }
    }
    private func save() {
        do {
            let selectedID = style == "photo" ? try photoData.map { try MountainAvatarPhotos.save($0) } ?? photoID : nil
            guard let data = MountainHumanProfile.updating(identity: identity, displayName: name, symbol: symbol, data: profiles, avatarStyle: style, photoID: selectedID) else { throw CocoaError(.fileWriteUnknown) }
            let changedDifficulty = difficulty != difficultyChoice
            if !adaptiveChoice || levelKey != "computerLevel" { MountainExperience.defaults.set(difficultyChoice.rawValue, forKey: levelKey) }
            MountainExperience.defaults.set(colorChoice, forKey: MountainStyle.colorKey(seat))
            profiles = data; difficulty = difficultyChoice; adaptive = adaptiveChoice; computer = computerChoice
            if changedDifficulty { onDifficultyChanged() }
            dismiss()
        } catch { failure = String(localized: "Your profile couldn't be saved. Try again.") }
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
                MountainExternalHome()
            }
        }.preferredColorScheme(.dark).statusBarHidden()
    }
}

/// The home screen as a connected display sees it: the same canopy and vine title, composed for
/// whatever shape the screen is, writing itself in as the phone's home screen does.
private struct MountainExternalHome: View {
    @State private var grow = 0.0
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage("animationsEnabled", store: MountainExperience.defaults) private var animationsEnabled = true
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let wide = size.width > size.height
            // Fill most of the height on a TV, and most of the width on a portrait screen.
            let width = min(size.width * (wide ? 0.42 : 0.78), size.height * 0.62 / MountainVineTitle.aspect)
            let frame = CGRect(x: (size.width - width) / 2, y: size.height * 0.1, width: width, height: width * MountainVineTitle.aspect)
            ZStack {
                MountainScenery(followsLocalTime: true, lush: true).overlay(MountainStyle.ink.opacity(0.4))
                MountainVineTitle(grow: grow, frame: frame)
                Text("Press Play on your iPhone or iPad")
                    .font(.system(size: max(18, size.height * 0.032), weight: .semibold))
                    .foregroundStyle(MountainStyle.cream)
                    .padding(.horizontal, 28).padding(.vertical, 14)
                    .background(MountainStyle.ink.opacity(0.7), in: Capsule())
                    .position(x: size.width / 2, y: min(size.height - 60, frame.maxY + size.height * 0.1))
            }
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .combine)
        .task {
            if systemReduceMotion || !animationsEnabled { grow = 1; return }
            try? await Task.sleep(for: .milliseconds(400))
            withAnimation(.easeInOut(duration: 4.2)) { grow = 1 }
        }
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
    @AppStorage("complexity", store: MountainExperience.defaults) private var size = 6
    @AppStorage("boardScrollThreshold", store: MountainExperience.defaults) private var threshold = 7
    @AppStorage("showStatusBar", store: MountainExperience.defaults) private var statusBar = false
    @AppStorage("animationsEnabled", store: MountainExperience.defaults) private var animations = true
    @AppStorage("hapticsEnabled", store: MountainExperience.defaults) private var haptics = true
    @AppStorage("computerMoveDuration", store: MountainExperience.defaults) private var duration = 0.7
    @AppStorage(MountainReminders.dailyKey, store: MountainExperience.defaults) private var dailyReminder = false
    @AppStorage(MountainReminders.timeKey, store: MountainExperience.defaults) private var reminderMinutes = 18 * 60
    @AppStorage(MountainReminders.unfinishedKey, store: MountainExperience.defaults) private var unfinishedReminder = false
    @State private var notificationsBlocked = false
    @AppStorage("friendAutomaticMoves", store: MountainExperience.defaults) private var automaticMoves = true
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    /// "None" is the old Reduced motion switch; any pace turns animation back on.
    private var motion: Binding<Double> {
        Binding(get: { animations ? duration : 0 }, set: { if $0 == 0 { animations = false } else { animations = true; duration = $0 } })
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
#if os(iOS)
                    group("Look") {
                        row("iphone", tint: MountainStyle.mint, "Status bar", detail: "Shows the time and battery during a game.") { EmptyView() } trailing: {
                            Toggle("Status bar", isOn: $statusBar).labelsHidden().accessibilityIdentifier("show-status-bar")
                        }
                    }
#endif
                    group("Board") {
                        row("square.grid.3x3.fill", tint: MountainStyle.gold, "Board size", detail: "Applies to your next game.") { EmptyView() } trailing: {
                            MountainCounter(title: "Board size", value: $size, range: 4...14).accessibilityIdentifier("board-size-setting")
                        }
                        divider
                        row("arrow.left.and.right.square.fill", tint: MountainStyle.mint, "Fit on screen up to", detail: "Bigger boards scroll sideways on a phone. A higher limit means smaller tiles.") { EmptyView() } trailing: {
                            MountainCounter(title: "Fit on screen up to", value: $threshold, range: 4...14).accessibilityIdentifier("board-scroll-threshold")
                        }
                    }
                    group("Feel") {
                        row("wand.and.stars", tint: MountainStyle.gold, "Animation", detail: "None keeps everything still. Your device’s Reduce Motion setting always applies.") {
                            Picker("Animation", selection: motion) {
                                Text("None").tag(0.0); Text("Fast").tag(0.4); Text("Natural").tag(0.7); Text("Relaxed").tag(1.2)
                            }.pickerStyle(.segmented).labelsHidden().accessibilityIdentifier("computer-speed-setting")
                        }
#if os(iOS)
                        divider
                        row("hand.tap.fill", tint: MountainStyle.mint, "Haptics", detail: "A light tap for each move and the win.") { EmptyView() } trailing: {
                            Toggle("Haptics", isOn: $haptics).labelsHidden().accessibilityIdentifier("haptics-setting")
                        }
#endif
                    }
                    group("Friend games") {
                        row("timer", tint: MountainStyle.mint, "Automatic moves", detail: "In new friend games, if a player waits 12 hours, the largest number on their line is taken for them. Either player can change it on their turn.") { EmptyView() } trailing: {
                            Toggle("Automatic moves", isOn: $automaticMoves).labelsHidden().accessibilityIdentifier("automatic-moves-default")
                        }
                    }
                    notificationGroup
                }.padding(20).frame(maxWidth: 560).frame(maxWidth: .infinity)
            }.background(MountainStyle.ink)
                .task { notificationsBlocked = await MountainReminders.blocked() }
                .navigationTitle("Settings").mountainInlineTitle()
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.keyboardShortcut(.defaultAction) } }
        }.tint(MountainStyle.gold).foregroundStyle(MountainStyle.cream).preferredColorScheme(.dark)
    }
    private var reminderTime: Binding<Date> {
        Binding(get: { Calendar.current.date(bySettingHour: reminderMinutes / 60, minute: reminderMinutes % 60, second: 0, of: .now) ?? .now },
                set: { let parts = Calendar.current.dateComponents([.hour, .minute], from: $0); reminderMinutes = (parts.hour ?? 18) * 60 + (parts.minute ?? 0) })
    }
    /// Turning a reminder on asks for permission first; a refusal leaves it off and points to system Settings.
    private func enable(_ on: Bool, _ apply: @escaping (Bool) -> Void) {
        guard on else { apply(false); MountainReminders.refresh(); return }
        Task {
            let allowed = await MountainReminders.requestPermission()
            notificationsBlocked = !allowed
            apply(allowed); MountainReminders.refresh()
        }
    }
    private var notificationGroup: some View {
        group("Notifications") {
            row("bell.fill", tint: MountainStyle.gold, "Daily reminder", detail: "A gentle nudge to come back and play.") {
                if dailyReminder {
                    DatePicker("Reminder time", selection: reminderTime, displayedComponents: .hourAndMinute)
                        .onChange(of: reminderMinutes) { MountainReminders.refresh() }
                        .accessibilityIdentifier("reminder-time")
                }
            } trailing: {
                Toggle("Daily reminder", isOn: Binding(get: { dailyReminder }, set: { on in enable(on) { dailyReminder = $0 } }))
                    .labelsHidden().accessibilityIdentifier("daily-reminder")
            }
            divider
            row("hourglass", tint: MountainStyle.mint, "Unfinished games", detail: "A reminder a day after you leave a game partway through.") { EmptyView() } trailing: {
                Toggle("Unfinished games", isOn: Binding(get: { unfinishedReminder }, set: { on in enable(on) { unfinishedReminder = $0 } }))
                    .labelsHidden().accessibilityIdentifier("unfinished-reminder")
            }
            divider
            row("person.2.fill", tint: MountainStyle.gold, "Friend turns and invites", detail: notificationsBlocked ? "Notifications are off for Tally Tangle. Turn them on in Settings." : "Game Center sends these. Choose sounds, banners and badges in Settings.") { EmptyView() } trailing: {
                Button("Open") { if let url = MountainReminders.systemSettingsURL { openURL(url) } }
                    .buttonStyle(.plain).font(.subheadline.weight(.semibold)).padding(.horizontal, 14).frame(minHeight: 36)
                    .background(MountainStyle.cream.opacity(0.12), in: Capsule()).accessibilityIdentifier("notification-settings")
                    .accessibilityLabel("Open notification settings")
            }
        }
    }
    private var divider: some View { Rectangle().fill(MountainStyle.cream.opacity(0.1)).frame(height: 1).padding(.leading, 64) }
    private func group<Content: View>(_ title: LocalizedStringResource, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.footnote.weight(.bold)).textCase(.uppercase).tracking(1)
                .foregroundStyle(MountainStyle.cream.opacity(0.65)).padding(.leading, 6).accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) { content() }
                .background(MountainStyle.cream.opacity(0.07), in: RoundedRectangle(cornerRadius: 20))
                .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(MountainStyle.cream.opacity(0.1), lineWidth: 1) }
        }
    }
    /// Icon, title and plain-language detail, with a control beside it or below it.
    private func row<Below: View, Trailing: View>(_ symbol: String, tint: Color, _ title: LocalizedStringResource, detail: LocalizedStringResource,
                                                   @ViewBuilder below: () -> Below, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Image(systemName: symbol).font(.body.weight(.semibold)).foregroundStyle(MountainStyle.ink)
                    .frame(width: 34, height: 34).background(tint, in: RoundedRectangle(cornerRadius: 9)).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body.weight(.semibold))
                    Text(detail).font(.footnote).foregroundStyle(MountainStyle.cream.opacity(0.7)).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
                trailing()
            }
            below()
        }.padding(.horizontal, 16).padding(.vertical, 14)
    }
}

/// A large, labelled minus/value/plus control; the desktop stepper's arrows are too small to read.
private struct MountainCounter: View {
    let title: LocalizedStringResource
    @Binding var value: Int
    let range: ClosedRange<Int>
    var body: some View {
        HStack(spacing: 4) {
            step("minus", by: -1)
            Text(verbatim: "\(value) × \(value)").font(.headline).monospacedDigit().frame(minWidth: 64)
            step("plus", by: 1)
        }
        .padding(4).background(MountainStyle.ink, in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title)).accessibilityValue("\(value) × \(value)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(range.upperBound, value + 1)
            case .decrement: value = max(range.lowerBound, value - 1)
            @unknown default: break
            }
        }
    }
    private func step(_ symbol: String, by delta: Int) -> some View {
        let next = value + delta
        return Button { value = next } label: {
            Image(systemName: symbol).font(.body.weight(.bold)).frame(width: 36, height: 36)
                .background(MountainStyle.cream.opacity(0.12), in: Circle())
        }.buttonStyle(.plain).disabled(!range.contains(next)).opacity(range.contains(next) ? 1 : 0.35)
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
                    Text("Share your tangle").font(MountainStyle.display(28))
                    if let exported {
                        ShareLink(item: exported, subject: Text("Tally Tangle"), message: Text("Tally Tangle · https://apps.apple.com/app/id971329310")) {
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
                catch { if !Task.isCancelled { failure = String(localized: "The replay couldn't be prepared. Your saved game is unchanged.") } }
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
        let url = folder.appendingPathComponent(history == nil ? "Tally-Tangle-final.png" : "Tally-Tangle-replay.gif")
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
            Text("Tally Tangle").font(MountainStyle.display(28))
            HStack {
                ForEach(0..<2, id: \.self) { player in
                    VStack(spacing: 4) {
                        Text(names[player]).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                        Text("\(game.scores[player])").font(.system(size: 24, weight: .bold)).monospacedDigit()
                    }.frame(maxWidth: .infinity).foregroundStyle(MountainStyle.player(player))
                }
            }
            Text(game.isOver ? game.scores[0] == game.scores[1] ? String(localized: "A tie!") : String(localized: "\(names[game.scores[0] > game.scores[1] ? 0 : 1]) wins!") : selected == nil ? String(localized: "The tangle begins") : String(localized: "+\(points) points · Move \(game.moves)"))
                .font(.system(size: 16, weight: .semibold)).lineLimit(1)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(side), spacing: 3), count: game.size), spacing: 3) {
                ForEach(game.tiles) { tile in
                    let label: String = tile.value != 0 ? String(tile.value) : selected == tile.id ? "+" + String(points) : "·"
                    Text(verbatim: label)
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

/// The end of a round, shown in place: both totals tally up, then the winner's card blooms.
struct MountainFinishPanel: View {
    let result: String
    let names: [String]
    let scores: [Int]
    let humanVictory: Bool
    let reduceMotion: Bool
    let haptics: Bool
    @State private var tally = 0.0
    @State private var landed = false
    private var winner: Int? { scores[0] == scores[1] ? nil : scores[0] > scores[1] ? 0 : 1 }
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "laurel.leading")
                Text(result).font(MountainStyle.display(28)).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
                Image(systemName: "laurel.trailing")
            }
            .font(.title).foregroundStyle(MountainStyle.gold)
            .symbolEffect(.pulse, options: .repeating, isActive: landed && !reduceMotion)
            HStack(spacing: 14) { card(0); card(1) }
        }
        .padding(14).frame(maxWidth: 620)
        .background(MountainStyle.ink.opacity(0.55), in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(result) \(names[0]) \(scores[0]), \(names[1]) \(scores[1]).")
#if !os(visionOS)
        .sensoryFeedback(humanVictory ? .success : .impact(flexibility: .soft), trigger: landed) { _, done in haptics && done && !MountainExperience.isQAActive }
#endif
        .onAppear {
            guard !reduceMotion else { tally = 1; landed = true; return }
            withAnimation(.easeOut(duration: 1.1).delay(0.25)) { tally = 1 } completion: {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { landed = true }
            }
        }
    }
    private func card(_ player: Int) -> some View {
        let won = winner == player
        return VStack(spacing: 4) {
            Image(systemName: won ? "crown.fill" : winner == nil ? "leaf.fill" : "leaf")
                .font(.title3).opacity(landed ? 1 : 0)
            Text(names[player]).font(.subheadline.weight(.semibold)).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            MountainScoreNumber(value: Double(scores[player]) * tally).font(MountainStyle.display(won && landed ? 42 : 34))
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10).padding(.horizontal, 10)
        .foregroundStyle(MountainStyle.player(player))
        .background(MountainStyle.player(player).opacity(won && landed ? 0.22 : 0.07), in: RoundedRectangle(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(MountainStyle.player(player).opacity(won && landed ? 0.9 : 0.2), lineWidth: won && landed ? 2.5 : 1) }
        .scaleEffect(won && landed && !reduceMotion ? 1.04 : 1)
        .opacity(landed && winner != nil && !won ? 0.7 : 1)
    }
}

/// The final board coloured by who claimed each square, replayed in move order. Tap to replay.
struct MountainFinishBoard: View {
    let game: MountainGame
    let history: MountainHistory?
    let names: [String]
    let reduceMotion: Bool
    @State private var shown = 0
    @State private var replay = 0
    /// Tile → (player, points) in move order; empty for old saves without a transcript.
    private var claims: [(tile: Int, player: Int, points: Int)] {
        guard let history, history.matches(game), let states = history.states else { return [] }
        return history.choices.enumerated().map { (tile: $1, player: states[$0].turn, points: history.initial.tiles[$1].value) }
    }
    private func summary(_ claims: [(tile: Int, player: Int, points: Int)]) -> String {
        guard !claims.isEmpty else { return "" }
        let first = claims.filter { $0.player == 0 }.count, second = claims.count - first
        return String(localized: "\(names[0]): \(first) squares.") + " " + String(localized: "\(names[1]): \(second) squares.")
    }
    var body: some View {
        let claims = self.claims
        let owner = Dictionary(uniqueKeysWithValues: claims.prefix(shown).enumerated().map { ($1.tile, ($1.player, $1.points, $0)) })
        GeometryReader { proxy in
            let n = CGFloat(game.size), gap: CGFloat = n > 8 ? 2 : 3
            let side = max(0, min(proxy.size.width, proxy.size.height))
            let cell = (side - gap * (n - 1)) / n
            VStack(spacing: gap) {
                ForEach(0..<game.size, id: \.self) { r in
                    HStack(spacing: gap) {
                        ForEach(0..<game.size, id: \.self) { c in
                            let id = r * game.size + c
                            let claim: (Int, Int, Int)? = owner[id]
                            let remaining: Int = game.tiles[id].value
                            let label: String = claim.map { String($0.1) } ?? (remaining > 0 ? String(remaining) : "")
                            let fill: Color = claim.map { MountainStyle.player($0.0) } ?? MountainStyle.cream.opacity(0.08)
                            let ink: Color = claim == nil ? MountainStyle.cream.opacity(0.45) : MountainStyle.ink
                            let latest: Bool = claim?.2 == shown - 1 && shown < claims.count
                            let corner: CGFloat = cell * 0.18
                            Text(verbatim: label)
                                .font(.system(size: max(6, cell * 0.4), weight: .bold)).monospacedDigit().minimumScaleFactor(0.5)
                                .frame(width: cell, height: cell)
                                .foregroundStyle(ink)
                                .background(fill, in: RoundedRectangle(cornerRadius: corner))
                                .overlay { RoundedRectangle(cornerRadius: corner).strokeBorder(MountainStyle.cream, lineWidth: latest ? 2 : 0) }
                                .scaleEffect(claim?.2 == shown - 1 && shown < claims.count && !reduceMotion ? 1.12 : 1)
                        }
                    }
                }
            }
            .frame(width: side, height: side).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .contentShape(Rectangle())
        .onTapGesture { replay += 1 }
        .task(id: replay) {
            guard !reduceMotion, claims.count > 0 else { shown = claims.count; return }
            shown = 0
            let step = min(0.25, 3.0 / Double(claims.count))
            try? await Task.sleep(for: .seconds(0.6))
            while shown < claims.count, !Task.isCancelled {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { shown += 1 }
                try? await Task.sleep(for: .seconds(step))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Final board")
        .accessibilityValue(summary(claims))
        .accessibilityHint("Replays the game")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("finish-board")
    }
}

/// A brief leaf bloom wherever the player touches the background. Decorative only.
struct MountainTouchBlooms: ViewModifier {
    let enabled: Bool
    @State private var blooms: [(id: UUID, point: CGPoint)] = []
    /// Where the finger or pointer is held; resets on its own if the system cancels the touch.
    @GestureState private var held: CGPoint?
    func body(content: Content) -> some View {
        content
            // A bud follows the press, including while dragging, then opens where it's released.
            .simultaneousGesture(DragGesture(minimumDistance: 0)
                .updating($held) { touch, state, _ in if enabled { state = touch.location } }
                .onEnded { touch in
                    guard enabled else { return }
                    let id = UUID()
                    blooms = Array((blooms + [(id, touch.location)]).suffix(6))
                    Task { try? await Task.sleep(for: .seconds(0.8)); blooms.removeAll { $0.id == id } }
                })
            .overlay(alignment: .topLeading) {
                ZStack(alignment: .topLeading) {
                    if let held { MountainBud().position(held) }
                    ForEach(blooms, id: \.id) { bloom in MountainBloom().position(bloom.point) }
                }.allowsHitTesting(false).accessibilityHidden(true)
            }
    }
}
/// A ring that tightens and a closed bud that swells under the finger.
private struct MountainBud: View {
    @State private var closed = false
    var body: some View {
        ZStack {
            Circle().strokeBorder(MountainStyle.cream.opacity(0.7), lineWidth: 2)
                .frame(width: 44, height: 44).scaleEffect(closed ? 0.45 : 1)
            ForEach(0..<3, id: \.self) { i in
                Ellipse().fill(Color(red: 0.42, green: 0.74, blue: 0.36))
                    .frame(width: 5, height: 11).offset(y: closed ? -5 : -14)
                    .rotationEffect(.degrees(Double(i) * 120 + (closed ? 0 : -30)))
            }
        }
        .opacity(closed ? 0.95 : 0)
        .onAppear { withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { closed = true } }
    }
}
private struct MountainBloom: View {
    @State private var open = false
    var body: some View {
        ZStack {
            Circle().strokeBorder(MountainStyle.gold.opacity(0.5), lineWidth: 1.5)
                .frame(width: 18, height: 18).scaleEffect(open ? 3 : 0.4)
            ForEach(0..<6, id: \.self) { i in
                Ellipse().fill(Color(red: 0.42, green: 0.74, blue: 0.36))
                    .frame(width: 6, height: 12)
                    .offset(y: open ? -26 : -4)
                    .rotationEffect(.degrees(Double(i) * 60 + (open ? 40 : 0)))
            }
        }
        .opacity(open ? 0 : 1)
        .onAppear { withAnimation(.easeOut(duration: 0.7)) { open = true } }
    }
}

/// Local reminders only. Friend-game turns and invitations come from Game Center, whose
/// banners and sounds people manage in the system's notification settings.
enum MountainReminders {
    static let dailyKey = "reminderDaily", timeKey = "reminderMinutes", unfinishedKey = "reminderUnfinished"
    private static let dailyID = "daily-reminder", unfinishedID = "unfinished-game"
    /// The notification center aborts outside an app bundle (command-line checks), so those skip it.
    private static var center: UNUserNotificationCenter? { Bundle.main.bundleIdentifier == nil ? nil : .current() }
    private static var defaults: UserDefaults { MountainExperience.defaults }
    static var systemSettingsURL: URL? {
#if os(macOS)
        URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")
#elseif os(iOS)
        URL(string: UIApplication.openNotificationSettingsURLString)
#else
        URL(string: UIApplication.openSettingsURLString)
#endif
    }
    static func requestPermission() async -> Bool {
        (try? await center?.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }
    static func blocked() async -> Bool { await center?.notificationSettings().authorizationStatus == .denied }
    /// Reschedules the daily reminder from the stored switch and time.
    static func refresh() {
        center?.removePendingNotificationRequests(withIdentifiers: [dailyID])
        guard !MountainExperience.isQAActive, defaults.bool(forKey: dailyKey) else { return }
        let minutes = defaults.object(forKey: timeKey) as? Int ?? 18 * 60
        let content = UNMutableNotificationContent()
        content.title = "Tally Tangle"
        content.body = String(localized: "The vines are ready for another game.")
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: minutes / 60, minute: minutes % 60), repeats: true)
        center?.add(UNNotificationRequest(identifier: dailyID, content: content, trigger: trigger))
    }
    static func scheduleUnfinished() {
        guard !MountainExperience.isQAActive, defaults.bool(forKey: unfinishedKey) else { return }
        let content = UNMutableNotificationContent()
        content.title = "Tally Tangle"
        content.body = String(localized: "Your game is waiting for your next move.")
        content.sound = .default
        center?.add(UNNotificationRequest(identifier: unfinishedID, content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 24 * 60 * 60, repeats: false)))
    }
    static func cancelUnfinished() { center?.removePendingNotificationRequests(withIdentifiers: [unfinishedID]) }
}

private struct MountainTitleAnchor: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) { value = nextValue() ?? value }
}

/// Marketing capture (DEBUG only): `-MountainShowcase <n>` with a private QA session opens a
/// prepared, deterministic scene. Games are real: every move comes from the game's own AI.
enum MountainShowcase {
    static var freezesComputer: Bool { scene != nil }
#if DEBUG
    enum Home { case title, settings, help, history(MountainGameCategory) }
    enum Overlay { case none, replay, editor(Int), settings }
    struct Scene {
        var home = Home.title
        var titleGrow: Double? = nil
        var tutorialSteps = 0
        var game: SavedMountainGame? = nil
        var overlay = Overlay.none
        var library: [SavedMountainGame] = []
    }
    private struct Seeded: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
    }
    /// Plays `moves` real AI moves (or to the end) on a seeded board. `wanted` keeps trying seeds
    /// until the finished game has the requested winner seat.
    private static func play(size: Int, seed: UInt64, moves: Int? = nil, levels: [ComputerDifficulty], wanted: Int? = nil,
                             names: [String], computers: [Bool], rival: ComputerDifficulty, first: ComputerDifficulty? = nil) -> SavedMountainGame {
        for attempt in 0..<40 {
            var random = Seeded(state: seed &+ UInt64(attempt) &* 7919)
            let values = Array(1...(size * size)).shuffled(using: &random)
            var game = MountainGame(size: size, values: values, firstPlayer: 0, startingLine: Int(seed % UInt64(size)))
            var history = MountainHistory(initial: game)
            var replay: MountainReplay?
            while !game.isOver && game.moves < (moves ?? .max) {
                // ponytail: capped search depth keeps setup instant in Debug; the boards only need to look like real play.
                let level = levels[game.turn].rawValue <= 11 ? levels[game.turn] : .level12
                guard let move = game.computerMove(difficulty: level, roll: 0.5, using: &random) else { break }
                if computers[game.turn] { replay = MountainReplay(before: game, tileID: move, difficulty: game.turn == 0 && computers[1] ? first ?? rival : rival) }
                history.record(move, before: game); game.play(move)
            }
            if let wanted, !(game.isOver && game.scores[wanted] > game.scores[1 - wanted]) { continue }
            var saved = SavedMountainGame(size: size, names: names, computers: computers, difficulty: rival, adjustment: 0)
            saved.game = game; saved.history = history; saved.replay = replay; saved.computerStarted = true
            saved.firstDifficulty = first; saved.recorded = game.isOver
            return saved
        }
        preconditionFailure("No seeded game reached the requested result")
    }
    private static let you = ["Maya", "Player 2"]
    private static func versus(_ size: Int, _ seed: UInt64, moves: Int? = nil, rival: ComputerDifficulty, wanted: Int? = nil) -> SavedMountainGame {
        play(size: size, seed: seed, moves: moves, levels: [wanted == 1 ? .level2 : .level12, wanted == 0 ? .level2 : rival], wanted: wanted, names: you, computers: [false, true], rival: rival)
    }
    private static func friends(_ size: Int, _ seed: UInt64, moves: Int? = nil, wanted: Int? = nil) -> SavedMountainGame {
        play(size: size, seed: seed, moves: moves, levels: [.level12, .level12], wanted: wanted, names: ["Maya", "Leo"], computers: [false, false], rival: .level6)
    }
    private static func bots(_ size: Int, _ seed: UInt64, moves: Int? = nil, _ a: ComputerDifficulty, _ b: ComputerDifficulty) -> SavedMountainGame {
        play(size: size, seed: seed, moves: moves, levels: [a, b], names: ["Player 1", "Player 2"], computers: [true, true], rival: b, first: a)
    }
    /// Colours per scene: index pairs into the player palette.
    static let colors: [Int: (Int, Int)] = [5: (2, 5), 6: (4, 6), 8: (3, 9), 10: (19, 17), 13: (13, 15), 25: (7, 11), 26: (16, 1), 27: (15, 9), 30: (6, 12)]

    static let scene: Scene? = {
        let args = ProcessInfo.processInfo.arguments
        guard MountainExperience.isQAActive, let flag = args.firstIndex(of: "-MountainShowcase"), args.indices.contains(flag + 1),
              let number = Int(args[flag + 1]) else { return nil }
        let defaults = MountainExperience.defaults
        let pair = colors[number] ?? (0, 1)
        defaults.set(pair.0, forKey: "player1Color"); defaults.set(pair.1, forKey: "player2Color")
        defaults.set(true, forKey: "hasPlayed"); defaults.set(6, forKey: "complexity")
        var profiles = Data()
        for (name, emoji) in [("Maya", "🦊"), ("Leo", "🐢")] {
            profiles = MountainHumanProfile.updating(identity: name, displayName: name, symbol: emoji, data: profiles, avatarStyle: "emoji") ?? profiles
        }
        defaults.set(profiles, forKey: "humanProfiles.v1")
        var history: [SavedMountainGame] { [versus(6, 41, rival: .level9, wanted: 0), versus(8, 42, rival: .level14, wanted: 1), versus(5, 43, moves: 9, rival: .level5),
                       friends(6, 44, wanted: 0), friends(4, 45, moves: 6), versus(7, 46, rival: .level17, wanted: 0), versus(4, 47, rival: .level2, wanted: 0)] }
        switch number {
        case 1: return Scene()
        case 2: return Scene(titleGrow: 0.5)
        case 3: return Scene(titleGrow: 0.7)
        case 4: return Scene(game: versus(6, 11, moves: 10, rival: .level18))
        case 5: return Scene(game: versus(4, 12, moves: 2, rival: .level1))
        case 6: return Scene(game: versus(8, 13, moves: 18, rival: .level16))
        case 7: return Scene(game: versus(10, 14, moves: 26, rival: .level17))
        case 8: return Scene(game: versus(14, 15, moves: 40, rival: .level13))
        case 9: return Scene(game: friends(6, 16, moves: 12))
        case 10: return Scene(game: bots(7, 17, moves: 14, .level17, .level18))
        case 11: return Scene(game: bots(5, 18, moves: 8, .level11, .level11))
        case 12: return Scene(game: versus(9, 19, moves: 16, rival: .level2))
        case 13: return Scene(game: versus(6, 20, rival: .level10, wanted: 0))
        case 14: return Scene(game: versus(8, 21, rival: .level18, wanted: 1))
        case 15: return Scene(game: friends(5, 22, wanted: 1))
        case 16: return Scene(game: bots(7, 23, .level15, .level18))
        case 17: return Scene(game: versus(4, 24, rival: .level1, wanted: 0))
        case 18: return Scene(home: .settings)
        case 19: return Scene(home: .history(.ai), library: history)
        case 20: return Scene(home: .history(.passAndPlay), library: history)
        case 21: return Scene(home: .help)
        case 22: return Scene(home: .help, tutorialSteps: 2)
        case 23: return Scene(home: .help, tutorialSteps: 4)
        case 24: return Scene(game: versus(6, 25, moves: 7, rival: .level12), overlay: .replay)
        case 25: return Scene(game: versus(6, 26, moves: 4, rival: .level15), overlay: .editor(1))
        case 26: return Scene(game: friends(6, 27, moves: 2), overlay: .editor(0))
        case 27: return Scene(game: versus(12, 28, moves: 30, rival: .level8))
        case 28: return Scene(game: versus(7, 29, moves: 12, rival: .level3))
        case 29: return Scene(game: versus(5, 30, moves: 6, rival: .level8))
        case 30: return Scene(game: versus(9, 31, rival: .level3, wanted: 0))
        // 31–33: one game in sequence — your turn, the move you just made, and the finished board.
        case 31: return Scene(game: versus(6, 32, moves: 8, rival: .level6))
        case 32: return Scene(game: versus(6, 32, moves: 9, rival: .level6))
        case 33: return Scene(game: versus(6, 32, rival: .level6))
        default: return nil
        }
    }()
#else
    static let scene: Never? = nil
#endif
}
