import SwiftUI

@main struct MountainTVApp: App {
    var body: some Scene { WindowGroup { MountainTVHome() } }
}

// Preserve the installed TV build's storage schema and keys.
struct TVSave: Codable {
    var game: MountainGame
    var history: [MountainGame]
    var difficulty: Int
    var local: Bool
}

private enum TVPage { case home, player, size, help, board }
private enum TVFocus: Hashable {
    case play, resume, player, size, help, rival(Int), local, boardSize(Int)
    case tile(Int), waiting, newGame, previousHelp, nextHelp, doneHelp, stay, leave
}
private enum TVMarker: Hashable { case tile(Int), score(Int) }
private struct TVMarkers: PreferenceKey {
    static var defaultValue: [TVMarker: CGRect] { [:] }
    static func reduce(value: inout [TVMarker: CGRect], nextValue: () -> [TVMarker: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
private struct TVTurnCue: Equatable {
    let tile: Int
    let player: Int
    let points: Int
    var flying = false
}

/// The shared title renderer uses the supplied width to scale both words, not its height.
private struct TVHomeVineTitle: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("animationsEnabled", store: MountainExperience.defaults) private var animationsEnabled = true
    @State private var grow = 0.0

    private var isStill: Bool { reduceMotion || !animationsEnabled }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            // Keep a canopy above the first line and extra canvas below the descenders.
            // Both words use a tall, two-line drawing; a wide text frame would crop it.
            let width = min(size.width * 0.65, size.height * 0.74 / MountainVineTitle.aspect)
            let height = width * MountainVineTitle.aspect
            let drawing = CGRect(x: (size.width - width) / 2, y: (size.height - height) / 2,
                                 width: width, height: height)
            MountainVineTitle(grow: isStill ? 1 : grow, frame: drawing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "Tally Tangle"))
        .accessibilityAddTraits(.isHeader)
        .task(id: isStill) {
            guard !isStill else { grow = 1; return }
            guard grow < 1 else { return }
            withAnimation(.easeInOut(duration: 3.0)) { grow = 1 }
        }
    }
}

private struct MountainTVHome: View {
    @Environment(\.scenePhase) private var phase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page: TVPage = .home
    @State private var homeFocus: TVFocus = .play
    @State private var game = MountainGame(size: 6)
    @State private var history: [MountainGame] = []
    @State private var claims: [Int: TVClaim] = [:]
    @State private var difficulty = 5
    @State private var local = false
    @State private var gameDifficulty = 5
    @State private var gameLocal = false
    @State private var size = 6
    @State private var savedGame = false
    @State private var leave = false
    @State private var slide = 0
    @State private var cue: TVTurnCue?
    @State private var turnTask: Task<Void, Never>?
    @State private var markers: [TVMarker: CGRect] = [:]
    @FocusState private var focus: TVFocus?
    private let defaults = MountainExperience.defaults
    private let space = "TV game stage"
    private var canAnimate: Bool { !reduceMotion && (defaults.object(forKey: "animationsEnabled") as? Bool ?? true) }
    private var rival: ComputerDifficulty { ComputerDifficulty(rawValue: gameDifficulty) ?? .level6 }

    private var showcase: Int? {
#if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if MountainExperience.isQAActive, let i = args.firstIndex(of: "-MountainShowcase"), args.indices.contains(i + 1) { return Int(args[i + 1]) }
#endif
        return nil
    }

    var body: some View {
        ZStack {
            MountainScenery(active: phase == .active && canAnimate, lush: true).ignoresSafeArea()
            LinearGradient(colors: [.black.opacity(0.67), MountainStyle.ink.opacity(0.2), .black.opacity(0.76)],
                           startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            switch page {
            case .home: landing
            case .player: playerPage
            case .size: sizePage
            case .help: helpPage
            case .board: board.disabled(leave).accessibilityHidden(leave)
            }
            if leave { leaveOverlay.zIndex(20) }
        }
        .overlay(alignment: .topLeading) { if page == .board && !leave { flight } }
        .coordinateSpace(name: space)
        .onPreferenceChange(TVMarkers.self) { markers = $0 }
        .foregroundStyle(MountainStyle.cream)
        .tint(MountainStyle.gold)
        .preferredColorScheme(.dark)
        .onAppear(perform: restore)
        .onOpenURL { url in
            guard url.scheme == "tallytangletv", url.host == "shelf", url.query == nil, url.fragment == nil,
                  page != .board else { return } // Never interrupt or replace a round in progress.
            switch url.path {
            case "/pick": slide = 0; open(.help, focus: .nextHelp)
            case "/score": slide = 2; open(.help, focus: .doneHelp)
            case "/together": open(.player, focus: .local)
            default: break
            }
        }
        .onDisappear { turnTask?.cancel(); cue = nil }
        .onChange(of: phase) { _, newPhase in if newPhase != .active && page == .board { persist() } }
        .task(id: "\(game.moves)-\(page)-\(phase)-\(leave)-\(cue != nil)") {
            guard page == .board, phase == .active, !leave, cue == nil, !gameLocal,
                  !game.isOver, game.turn == 1, showcase == nil else { return }
            let snapshot = game
            let level = rival
            do { try await Task.sleep(for: .milliseconds(580)) } catch { return }
            let thinking = Task.detached(priority: .userInitiated) { snapshot.computerMove(difficulty: level) }
            let selected = await thinking.value
            guard !Task.isCancelled, page == .board, phase == .active, !leave,
                  game.moves == snapshot.moves, game.turn == 1, let selected else { return }
            showMove(selected)
        }
        .onExitCommand(perform: page == .home ? nil : goBack)
    }

    private var leaveOverlay: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 23) {
                Text("Leave Game").font(MountainStyle.display(60)).accessibilityAddTraits(.isHeader)
                Text("You can continue this game from the home screen.").font(.system(size: 31))
                HStack(spacing: 20) {
                    action("Keep Playing", icon: "play.fill", key: .stay, strong: true) { cancelLeave() }
                    action("Leave Game", icon: "door.left.hand.open", key: .leave) {
                        persist()
                        turnTask?.cancel()
                        cue = nil
                        leave = false
                        open(.home, focus: .resume)
                    }
                }
            }
            .padding(42)
            .background(MountainStyle.ink, in: RoundedRectangle(cornerRadius: 34))
            .overlay(RoundedRectangle(cornerRadius: 34).strokeBorder(.white.opacity(0.25), lineWidth: 1))
        }
        .defaultFocus($focus, .stay)
    }

    private func cancelLeave() {
        leave = false
        focusBoard()
    }

    private var landing: some View {
        VStack(spacing: 12) {
            TVHomeVineTitle()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack(spacing: 22) {
                action("Play", icon: "play.fill", key: .play, strong: true) { start() }
                action("Continue", icon: "arrow.right.circle", key: .resume) { resume() }
                    .disabled(!savedGame)
                action("Player", icon: "person.crop.circle", key: .player) {
                    open(.player, focus: local ? .local : .rival(difficulty))
                }
                action("Board Size", icon: "square.grid.3x3", key: .size) { open(.size, focus: .boardSize(size)) }
                action("How to Play", icon: "questionmark.circle", key: .help) { slide = 0; open(.help, focus: .nextHelp) }
            }
            .padding(.vertical, 21)
            .padding(.horizontal, 26)
            .background(.black.opacity(0.56), in: RoundedRectangle(cornerRadius: 30))
            .padding(.bottom, 20)
        }
        .padding(.horizontal, 22)
        .defaultFocus($focus, homeFocus)
    }

    private var playerPage: some View {
        VStack(alignment: .leading, spacing: 19) {
            sectionTitle("Player", back: true)
            ScrollViewReader { scroll in
                ScrollView(.horizontal) {
                    LazyHStack(alignment: .center, spacing: 24) {
                        playerCard(nil)
                        ForEach(ComputerDifficulty.allCases) { playerCard($0) }
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 22)
                }
                .scrollClipDisabled()
                .onAppear {
                    let target: TVFocus = local ? .local : .rival(difficulty)
                    scroll.scrollTo(target, anchor: .center)
                    focus = target
                }
            }
        }
        .padding(.horizontal, 36)
        .padding(.vertical, 28)
        .defaultFocus($focus, local ? .local : .rival(difficulty))
    }

    private func playerCard(_ opponent: ComputerDifficulty?) -> some View {
        let key = opponent.map { TVFocus.rival($0.rawValue) } ?? .local
        let selected = opponent.map { !local && $0.rawValue == difficulty } ?? local
        let color = opponent.map { difficultyColor($0.rawValue) } ?? MountainStyle.mint
        return Button {
            local = opponent == nil
            if let opponent { difficulty = opponent.rawValue }
            defaults.set(local, forKey: "tv.local")
            defaults.set(difficulty, forKey: "tv.difficulty")
            open(.home, focus: .player)
        } label: {
            VStack(alignment: .leading, spacing: 13) {
                if let opponent {
                    portrait(opponent, side: 240)
                } else {
                    Image(systemName: "person.2.fill").font(.system(size: 79, weight: .semibold))
                        .foregroundStyle(MountainStyle.mint)
                        .frame(width: 240, height: 240)
                        .background(MountainStyle.mint.opacity(0.13), in: RoundedRectangle(cornerRadius: 20))
                        .accessibilityHidden(true)
                }
                HStack(spacing: 8) {
                    if let opponent { Text(verbatim: opponent.name) } else { Text("Pass & Play") }
                    Spacer(minLength: 2)
                    if selected { Image(systemName: "checkmark.circle.fill").foregroundStyle(MountainStyle.mint).accessibilityHidden(true) }
                }
                .font(.system(size: 32, weight: .bold, design: .serif))
                .lineLimit(2)
                .minimumScaleFactor(0.78)
                if let opponent {
                    Label { Text(verbatim: opponent.title) } icon: {
                        Circle().fill(color).overlay(Circle().strokeBorder(.white.opacity(0.66), lineWidth: 1.5))
                            .frame(width: 16, height: 16)
                    }
                    Text(verbatim: opponent.detail)
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(MountainStyle.cream.opacity(0.84))
                        .lineLimit(2)
                        .frame(minHeight: 53, alignment: .topLeading)
                } else {
                    Text("2 players").foregroundStyle(MountainStyle.mint)
                    Text("Take turns on the same TV.")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(MountainStyle.cream.opacity(0.84))
                        .frame(minHeight: 53, alignment: .topLeading)
                }
            }
            .font(.system(size: 22, weight: .semibold))
            .frame(width: 240, alignment: .leading)
            .padding(18)
            .background(.black.opacity(0.69), in: RoundedRectangle(cornerRadius: 25))
            .overlay(RoundedRectangle(cornerRadius: 25).strokeBorder(focus == key ? MountainStyle.cream : selected ? MountainStyle.mint : color, lineWidth: focus == key ? 3 : 1.5))
            .scaleEffect(focus == key && canAnimate ? 1.045 : 1)
            .animation(canAnimate ? .easeOut(duration: 0.17) : nil, value: focus == key)
        }
        .buttonStyle(TVActionStyle())
        .focusEffectDisabled()
        .focused($focus, equals: key)
        .id(key)
        .accessibilityIdentifier(opponent.map { "tv.rival.\($0.rawValue)" } ?? "tv.local")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private var sizePage: some View {
        let preview: Int = if case let .boardSize(candidate) = focus { candidate } else { size }
        return VStack(alignment: .leading, spacing: 20) {
            sectionTitle("Board Size", back: true)
            HStack(spacing: 58) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 15), count: 3), spacing: 15) {
                    ForEach(4...MountainGame.maximumBoardSize, id: \.self) { candidate in
                        let key = TVFocus.boardSize(candidate)
                        Button {
                            size = candidate
                            defaults.set(candidate, forKey: "tv.size")
                            open(.home, focus: .size)
                        } label: {
                            Text(verbatim: "\(candidate.formatted(.number)) × \(candidate.formatted(.number))")
                                .font(.system(size: 29, weight: .semibold, design: .monospaced))
                                .frame(maxWidth: .infinity, minHeight: 65)
                                .background(candidate == size ? MountainStyle.gold.opacity(0.25) : .black.opacity(0.61), in: RoundedRectangle(cornerRadius: 13))
                                .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(focus == key ? MountainStyle.cream : candidate == size ? MountainStyle.gold : .clear, lineWidth: 3))
                        }.buttonStyle(TVActionStyle()).focusEffectDisabled().focused($focus, equals: key)
                         .accessibilityAddTraits(candidate == size ? [.isSelected] : [])
                         .accessibilityIdentifier("tv.size.\(candidate)")
                    }
                }
                .frame(maxWidth: 600)
                .focusSection()
                VStack(spacing: 14) {
                    Text(verbatim: "\(preview.formatted(.number)) × \(preview.formatted(.number))").font(MountainStyle.display(48))
                        .accessibilityIdentifier("tv.size.preview")
                    BoardSizePreview(size: preview)
                        .frame(maxWidth: 510, maxHeight: 510)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, 36).padding(.vertical, 25)
        .defaultFocus($focus, .boardSize(size))
    }

    private var helpPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionTitle("How to Play", back: true)
            HStack(spacing: 65) {
                Image("Tutorial-\(slide + 1)")
                    .resizable().scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .frame(maxWidth: 730, maxHeight: 565)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 22) {
                    Text("\(slide + 1) of 3").font(.system(size: 24, weight: .semibold, design: .monospaced))
                        .foregroundStyle(MountainStyle.mint)
                    switch slide {
                    case 0:
                        Text("Pick from the row").font(MountainStyle.display(61))
                        Text("Choose a gold tile. Its number goes to your score.")
                    case 1:
                        Text("Then play the column").font(MountainStyle.display(61))
                        Text("The tile you pick opens its column for the second player.")
                    default:
                        Text("No moves left?").font(MountainStyle.display(61))
                        Text("The game ends when the next player has no legal tile. The higher score wins.")
                    }
                    HStack(spacing: 16) {
                        action("Previous", icon: "chevron.left", key: .previousHelp) { changeSlide(-1) }
                            .disabled(slide == 0)
                        if slide < 2 {
                            action("Next", icon: "chevron.right", key: .nextHelp, strong: true) { changeSlide(1) }
                        } else {
                            action("Done", icon: "checkmark", key: .doneHelp, strong: true) { goBack() }
                        }
                    }
                    .padding(.top, 14)
                }
                .font(.system(size: 29))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, 36).padding(.vertical, 25)
        .defaultFocus($focus, slide == 2 ? .doneHelp : .nextHelp)
    }

    private func sectionTitle(_ name: LocalizedStringKey, back: Bool) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(name).font(MountainStyle.display(66)).accessibilityAddTraits(.isHeader)
            Spacer()
            if back { Label("Back to home", systemImage: "chevron.left").font(.system(size: 23)).foregroundStyle(MountainStyle.cream.opacity(0.8)) }
        }
    }

    private var board: some View {
        GeometryReader { proxy in
            let boardSide = min(proxy.size.height - 30, proxy.size.width * 0.66, 800)
            HStack(spacing: 55) {
                VStack(alignment: .leading, spacing: 21) {
                    Text(verbatim: "Tally Tangle")
                        .font(MountainStyle.display(65)).lineLimit(1).minimumScaleFactor(0.66)
                        .accessibilityAddTraits(.isHeader)
                    score(0)
                    score(1)
                    turnMessage.font(.system(size: 25, weight: .semibold))
                        .focusable(!gameLocal && game.turn == 1 && !game.isOver)
                        .focused($focus, equals: .waiting)
                        .accessibilityIdentifier("tv.status")
                    if game.isOver && cue == nil {
                        Text("Small numbers show turn order.")
                            .font(.system(size: 23)).foregroundStyle(MountainStyle.cream.opacity(0.85))
                        action("New Game", icon: "plus", key: .newGame, strong: true) { start(usingCurrentPlayers: true) }
                    }
                }
                .padding(30)
                .frame(width: min(470, proxy.size.width * 0.35), alignment: .leading)
                .background(.black.opacity(0.47), in: RoundedRectangle(cornerRadius: 30))
                tileGrid(side: boardSide)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 15).padding(.vertical, 7)
        .defaultFocus($focus, game.isOver ? .newGame : !gameLocal && game.turn == 1 ? .waiting : game.legalMoves.first.map(TVFocus.tile) ?? .newGame)
    }

    @ViewBuilder private var turnMessage: some View {
        if let cue {
            if cue.player == 1 && !gameLocal {
                Label { Text("\(rival.name) picks \(cue.points)") } icon: { Image(systemName: "sparkle") }
                    .foregroundStyle(MountainStyle.mint)
            } else { Text("+\(cue.points) points") }
        } else if game.isOver {
            if game.scores[0] == game.scores[1] { Text("Tie game") }
            else { Text("\(playerName(game.scores[0] > game.scores[1] ? 0 : 1)) wins") }
        } else if !gameLocal && game.turn == 1 {
            Text("\(rival.name) is thinking")
        } else {
            Text(game.turn == 0 ? "Pick from the gold row" : "Pick from the mint column")
        }
    }

    private func score(_ seat: Int) -> some View {
        HStack(spacing: 14) {
            Group {
                if seat == 1 && !gameLocal {
                    portrait(rival, side: 70)
                } else {
                    Image(systemName: seat == 0 ? "circle.fill" : "diamond.fill")
                        .font(.system(size: 31, weight: .bold)).frame(width: 70, height: 70)
                        .accessibilityHidden(true)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: playerName(seat)).font(.system(size: 26, weight: .semibold))
                Text(game.scores[seat], format: .number)
                    .font(.system(size: 53, weight: .bold, design: .serif).monospacedDigit())
                    .background(marker(.score(seat)))
            }
        }
        .foregroundStyle(seatColor(seat))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: playerName(seat)))
        .accessibilityValue(Text(game.scores[seat], format: .number))
        .accessibilityIdentifier("tv.score.\(seat)")
    }

    private func tileGrid(side: CGFloat) -> some View {
        let gap: CGFloat = game.size > 10 ? 5 : 9
        let cell = (side - CGFloat(game.size - 1) * gap) / CGFloat(game.size)
        // A flat stack (no separate row/column stacks) gives zIndex one shared paint order.
        return ZStack(alignment: .topLeading) {
            ForEach(game.tiles) { tile in
                let key = TVFocus.tile(tile.id)
                let raised = focus == key || cue?.tile == tile.id
                let x = CGFloat(tile.id % game.size) * (cell + gap)
                let y = CGFloat(tile.id / game.size) * (cell + gap)
                let legal = game.canPlay(tile.id) && (gameLocal || game.turn == 0) && !game.isOver
                Group {
                    if legal {
                        Button {
                            guard cue == nil, gameLocal || game.turn == 0 else { return }
                            showMove(tile.id)
                        } label: {
                            tileFace(tile, cell: cell, focused: focus == key)
                        }
                        .buttonStyle(TVActionStyle()).focusEffectDisabled().focused($focus, equals: key)
                    } else {
                        tileFace(tile, cell: cell, focused: false)
                            .accessibilityElement(children: .ignore)
                    }
                }
                .frame(width: cell, height: cell)
                .scaleEffect(raised && canAnimate ? (game.size > 10 ? 1.08 : 1.12) : 1)
                .animation(canAnimate ? .easeOut(duration: 0.15) : nil, value: raised)
                .background(marker(.tile(tile.id)))
                .offset(x: x, y: y)
                .zIndex(raised ? 3 : 0)
                .accessibilityLabel(tileLabel(tile))
                .accessibilityIdentifier("tv.tile.\(tile.id)")
            }
        }
        .frame(width: side, height: side, alignment: .topLeading)
    }

    private func tileFace(_ tile: MountainGame.Tile, cell: CGFloat, focused: Bool) -> some View {
        let claim = claims[tile.id]
        let active = game.canPlay(tile.id)
        let picked = cue?.tile == tile.id
        let color = picked ? seatColor(cue?.player ?? game.turn) : game.isOver && claim != nil ? seatColor(claim?.player ?? 0) : active ? seatColor(game.turn) : MountainStyle.ink.opacity(0.84)
        let bright = picked || (game.isOver && claim != nil) || active
        return ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: min(15, cell * 0.16)).fill(color)
            Group {
                if game.isOver, let claim {
                    Image(systemName: claim.player == 0 ? "circle.fill" : "diamond.fill")
                        .font(.system(size: min(25, cell * 0.26), weight: .bold))
                } else if let value = picked ? cue?.points : (tile.value > 0 ? tile.value : nil) {
                    Text(value, format: .number)
                        .font(.system(size: min(43, cell * 0.39), weight: .bold, design: .rounded).monospacedDigit())
                }
            }
            .foregroundStyle(bright ? MountainStyle.ink : MountainStyle.cream.opacity(0.82))
            .frame(width: cell, height: cell, alignment: .center)
            if game.isOver, let claim {
                Text(claim.turn, format: .number)
                    .font(.system(size: max(10, min(22, cell * 0.24)), weight: .bold, design: .monospaced))
                    .foregroundStyle(MountainStyle.ink)
                    .padding(max(2, cell * 0.06))
            }
        }
        .frame(width: cell, height: cell)
        .overlay(RoundedRectangle(cornerRadius: min(15, cell * 0.16)).strokeBorder(focused || picked ? MountainStyle.cream : .white.opacity(0.08), lineWidth: focused || picked ? 3 : 1))
    }

    private func tileLabel(_ tile: MountainGame.Tile) -> Text {
        if game.isOver, let claim = claims[tile.id] {
            Text("Row \(tile.id / game.size + 1), column \(tile.id % game.size + 1), \(playerName(claim.player)), turn \(claim.turn)")
        } else {
            Text(verbatim: String(format: String(localized: "Row %lld, column %lld, %lld points"), locale: .current, Int64(tile.id / game.size + 1), Int64(tile.id % game.size + 1), Int64(tile.value)))
        }
    }

    @ViewBuilder private var flight: some View {
        if canAnimate, let cue, let from = markers[.tile(cue.tile)], let to = markers[.score(cue.player)] {
            Text("+\(cue.points)")
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .padding(.horizontal, 15).padding(.vertical, 7)
                .foregroundStyle(MountainStyle.ink)
                .background(seatColor(cue.player), in: Capsule())
                .shadow(color: .black.opacity(0.5), radius: 8)
                .scaleEffect(cue.flying ? 0.76 : 1)
                .position(x: cue.flying ? to.midX + 22 : from.midX, y: cue.flying ? to.midY - 20 : from.midY)
                .allowsHitTesting(false).accessibilityHidden(true)
        }
    }

    private func marker(_ key: TVMarker) -> some View {
        GeometryReader { proxy in
            Color.clear.preference(key: TVMarkers.self, value: [key: proxy.frame(in: .named(space))])
        }
    }

    private func portrait(_ opponent: ComputerDifficulty, side: CGFloat) -> some View {
        Group {
            if let artwork = opponent.portrait {
                Image(artwork).resizable().scaledToFill()
            } else {
                // The shared roster has no painting for Rosa or Wren.
                Image(systemName: opponent.name == "Rosa" ? "leaf.fill" : "bird.fill")
                    .font(.system(size: side * 0.32, weight: .medium))
                    .foregroundStyle(MountainStyle.cream)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(difficultyColor(opponent.rawValue).opacity(0.65))
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: min(22, side * 0.14)))
        .accessibilityHidden(true)
    }

    private func difficultyColor(_ level: Int) -> Color {
        if level == 17 { return .black }
        let t = Double(level) / 16
        if t < 0.5 { return Color(red: 0.16 + t * 1.36, green: 0.69 + t * 0.27, blue: 0.26 - t * 0.29) }
        let p = (t - 0.5) * 2
        return Color(red: 0.84 - p * 0.37, green: 0.825 - p * 0.74, blue: 0.115)
    }

    private func playerName(_ seat: Int) -> String {
        seat == 0 ? String(localized: "Player 1") : gameLocal ? String(localized: "Player 2") : rival.name
    }

    private func seatColor(_ seat: Int) -> Color { seat == 0 ? MountainStyle.gold : MountainStyle.mint }

    private func action(_ label: LocalizedStringKey, icon: String, key: TVFocus, strong: Bool = false,
                        perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            Label(label, systemImage: icon)
                .font(.system(size: 26, weight: .semibold))
                .lineLimit(1).minimumScaleFactor(0.65)
                .padding(.horizontal, 18).padding(.vertical, 14)
                .frame(minHeight: 61)
                .foregroundStyle(strong ? MountainStyle.ink : MountainStyle.cream)
                .background(strong ? MountainStyle.gold : .white.opacity(focus == key ? 0.23 : 0.08), in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(focus == key ? MountainStyle.cream : .white.opacity(0.2), lineWidth: focus == key ? 3 : 1))
        }
        .buttonStyle(TVActionStyle()).focusEffectDisabled().focused($focus, equals: key)
        .accessibilityIdentifier("tv.action.\(key)")
    }

    private func open(_ destination: TVPage, focus target: TVFocus?) {
        if destination == .home { homeFocus = target ?? .play }
        page = destination
        focus = target
    }

    private func goBack() {
        if leave { cancelLeave(); return }
        switch page {
        case .home: break
        case .player: open(.home, focus: .player)
        case .size: open(.home, focus: .size)
        case .help: open(.home, focus: .help)
        case .board:
            if game.isOver { persist(); open(.home, focus: .play) }
            else { leave = true; focus = .stay }
        }
    }

    private func changeSlide(_ offset: Int) {
        slide = min(2, max(0, slide + offset))
        focus = slide == 2 ? .doneHelp : .nextHelp
    }

    private func start(usingCurrentPlayers: Bool = false) {
        turnTask?.cancel(); cue = nil
        if !usingCurrentPlayers { gameDifficulty = difficulty; gameLocal = local }
        game = MountainGame(size: size); history = []; claims = [:]; page = .board
        persist(); focusBoard()
    }

    private func resume() {
        guard savedGame else { return }
        page = .board; focusBoard()
    }

    private func showMove(_ id: Int) {
        guard cue == nil, game.canPlay(id) else { return }
        let player = game.turn
        let sizeBefore = game.size
        let turnBefore = game.moves
        cue = TVTurnCue(tile: id, player: player, points: game.tiles[id].value)
        turnTask?.cancel()
        turnTask = Task { @MainActor in
            // Hold the CPU's actual chosen tile before points move, including with Reduce Motion.
            if !gameLocal && player == 1 {
                do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
            } else if canAnimate {
                // Give the points pill a display frame at its origin before starting the flight.
                do { try await Task.sleep(for: .milliseconds(35)) } catch { return }
            }
            guard !Task.isCancelled, page == .board, game.size == sizeBefore, game.moves == turnBefore else { return }
            if canAnimate {
                withAnimation(.easeInOut(duration: 0.33)) { cue?.flying = true }
                do { try await Task.sleep(for: .milliseconds(360)) } catch { return }
            }
            guard !Task.isCancelled, page == .board, game.moves == turnBefore, game.canPlay(id) else { return }
            history.append(game)
            game.play(id)
            claims[id] = TVClaim(player: player, turn: game.moves)
            cue = nil
            persist()
            focusBoard()
        }
    }

    private func focusBoard() {
        if game.isOver { focus = .newGame }
        else if gameLocal || game.turn == 0 { focus = game.legalMoves.first.map(TVFocus.tile) }
        else { focus = .waiting }
    }

    private func persist() {
        guard showcase == nil, page == .board,
              let data = try? JSONEncoder().encode(TVSave(game: game, history: history, difficulty: gameDifficulty, local: gameLocal)) else { return }
        defaults.set(data, forKey: "tv.game.v1")
        savedGame = true
    }

    private func restore() {
        size = min(MountainGame.maximumBoardSize, max(4, defaults.object(forKey: "tv.size") as? Int ?? 6))
        difficulty = min(17, max(0, defaults.object(forKey: "tv.difficulty") as? Int ?? 5))
        local = defaults.bool(forKey: "tv.local")
        if let n = showcase { stage(n); return }
        if let data = defaults.data(forKey: "tv.game.v1") {
            if let saved = try? JSONDecoder().decode(TVSave.self, from: data), saved.game.isValid,
               saved.history.count == saved.game.moves, saved.history.allSatisfy(\.isValid) {
                game = saved.game; history = saved.history
                gameDifficulty = min(17, max(0, saved.difficulty)); gameLocal = saved.local
                claims = TVClaim.reconstruct(history: history, final: game)
                savedGame = true
            } else {
                defaults.set(data, forKey: "tv.unreadable.game.v1")
            }
        }
    }

    private func stage(_ number: Int) {
        guard number > 1 else { return }
        if number == 2 || number == 18 {
            size = number == 2 ? 4 : 8
            open(number == 2 ? .player : .size, focus: number == 2 ? .rival(difficulty) : .boardSize(size))
            return
        }
        if number == 3 { open(.help, focus: .nextHelp); return }
        size = [4,5,6,7,8][number % 5]; gameDifficulty = number % 18; gameLocal = number % 7 == 0
        var rng = TVSeed(state: UInt64(number + 101))
        game = MountainGame(size: size, values: Array(1...(size * size)).shuffled(using: &rng), startingLine: number % size)
        history = []
        let count = [13,14,15,16,17,30].contains(number) ? size * size : number % (size * 2) + 2
        for _ in 0..<count {
            guard let move = game.computerMove(difficulty: .level6, roll: 0.4, using: &rng) else { break }
            history.append(game); game.play(move)
        }
        claims = TVClaim.reconstruct(history: history, final: game)
        page = .board; focusBoard()
    }
}

// Turn ownership can be reconstructed even for games saved by the currently installed release.
struct TVClaim: Equatable {
    let player: Int
    let turn: Int

    static func reconstruct(history: [MountainGame], final: MountainGame) -> [Int: TVClaim] {
        var claims: [Int: TVClaim] = [:]
        for (index, before) in history.enumerated() {
            let after = history.indices.contains(index + 1) ? history[index + 1] : final
            guard before.size == after.size, after.moves == before.moves + 1,
                  before.tiles.count == after.tiles.count else { continue }
            let changed = before.tiles.indices.filter { before.tiles[$0].value != after.tiles[$0].value }
            if let id = changed.first, changed.count == 1, before.canPlay(id),
               after.tiles[id].value == 0, claims[id] == nil {
                claims[id] = TVClaim(player: before.turn, turn: after.moves)
            }
        }
        return claims
    }
}

private struct TVActionStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(enabled ? (configuration.isPressed ? 0.83 : 1) : 0.44)
    }
}

private struct BoardSizePreview: View {
    let size: Int
    var body: some View {
        Canvas { context, frame in
            let side = min(frame.width, frame.height)
            let origin = CGPoint(x: (frame.width - side) / 2, y: (frame.height - side) / 2)
            let gap: CGFloat = 4
            let cell = (side - gap * CGFloat(size - 1)) / CGFloat(size)
            for row in 0..<size {
                for column in 0..<size {
                    let x = origin.x + CGFloat(column) * (cell + gap)
                    let y = origin.y + CGFloat(row) * (cell + gap)
                    let box = CGRect(x: x, y: y, width: cell, height: cell)
                    let tile = Path(roundedRect: box, cornerRadius: min(cell * 0.2, 10))
                    context.fill(tile, with: .color(row == size / 2 ? MountainStyle.gold : MountainStyle.cream.opacity(0.21)))
                }
            }
        }
    }
}

private struct TVSeed: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
}
