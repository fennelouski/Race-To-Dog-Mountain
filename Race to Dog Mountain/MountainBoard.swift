import SwiftUI

struct MountainButton: ButtonStyle {
    var prominent = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage("animationsEnabled", store: MountainExperience.defaults) private var animationsEnabled = true
    private var reduceMotion: Bool { systemReduceMotion || !animationsEnabled }
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

/// Squashes on press and springs back on release.
struct MountainPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage("animationsEnabled", store: MountainExperience.defaults) private var animationsEnabled = true
    func makeBody(configuration: Configuration) -> some View {
        let still = systemReduceMotion || !animationsEnabled
        configuration.label
            .scaleEffect(configuration.isPressed && !still ? 0.93 : 1)
            .brightness(configuration.isPressed ? 0.06 : 0)
            .animation(still ? nil : .spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// The home screen's big round Play button, ringed by a slow breathing glow.
struct MountainPlayButton: View {
    var size: CGFloat = 168
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage("animationsEnabled", store: MountainExperience.defaults) private var animationsEnabled = true
    @State private var breathing = false
    var body: some View {
        let still = systemReduceMotion || !animationsEnabled
        Button(action: action) {
            Text("Play").font(MountainStyle.display(size * 0.22)).foregroundStyle(MountainStyle.ink)
                .frame(width: size, height: size)
                .background(MountainStyle.gold, in: Circle())
                .shadow(color: .black.opacity(0.35), radius: 18, y: 10)
                .contentShape(Circle())
        }
        .buttonStyle(MountainPressStyle()).mountainHover()
        .background {
            Circle().stroke(MountainStyle.gold.opacity(breathing ? 0 : 0.55), lineWidth: 10)
                .scaleEffect(breathing ? 1.28 : 1).allowsHitTesting(false)
        }
        .onAppear { if !still { withAnimation(.easeOut(duration: 2.4).repeatForever(autoreverses: false)) { breathing = true } } }
    }
}

/// Role is encoded by the pair of edges; turn emphasis changes only the overlay.
struct MountainPlayerHighlight: View {
    let player: Int
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage("animationsEnabled", store: MountainExperience.defaults) private var animationsEnabled = true
    var body: some View {
        MountainPlayerEdges(horizontal: player == 0)
            .stroke(MountainStyle.player(player).opacity(active ? 0.95 : 0.26),
                    style: StrokeStyle(lineWidth: active ? 3 : 1.25, lineCap: .round))
            .animation(systemReduceMotion || !animationsEnabled ? nil : .easeInOut(duration: 0.2), value: active)
            .allowsHitTesting(false).accessibilityHidden(true)
    }
}
private struct MountainPlayerEdges: Shape {
    let horizontal: Bool
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let inset = min(18.0, min(rect.width, rect.height) * 0.2)
        if horizontal {
            for y in [1.5, rect.height - 1.5] {
                path.move(to: CGPoint(x: inset, y: y)); path.addLine(to: CGPoint(x: rect.width - inset, y: y))
            }
        } else {
            for x in [1.5, rect.width - 1.5] {
                path.move(to: CGPoint(x: x, y: inset)); path.addLine(to: CGPoint(x: x, y: rect.height - inset))
            }
        }
        return path
    }
}

private struct MountainTileButton: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage("animationsEnabled", store: MountainExperience.defaults) private var animationsEnabled = true
    private var reduceMotion: Bool { systemReduceMotion || !animationsEnabled }
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            // Pressing down tucks the tile in and draws a glowing ring; releasing springs it back.
            .overlay {
                RoundedRectangle(cornerRadius: 12).strokeBorder(MountainStyle.cream, lineWidth: 3)
                    .padding(configuration.isPressed ? 3 : -6)
                    .opacity(configuration.isPressed && !reduceMotion ? 0.9 : 0)
            }
            .brightness(configuration.isPressed ? 0.08 : 0)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.88 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.6), value: configuration.isPressed)
    }
}


struct MountainBoard: View {
    let game: MountainGame
    let availableWidth: CGFloat
    var availableHeight: CGFloat? = nil
    var fitAllSizes = false
    var numberScale: CGFloat = 1
    @AppStorage("boardScrollThreshold", store: MountainExperience.defaults) private var scrollThreshold = 7
#if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif
    var interactive = false
    var lastMove: Int?
    var lastPoints = 0
    var selected: Int?
    var select: (Int) -> Void = { _ in }
#if os(visionOS)
    @ScaledMetric(relativeTo: .title3) private var minimumTile: CGFloat = 60
#else
    @ScaledMetric(relativeTo: .title3) private var minimumTile: CGFloat = 44
#endif
    @Namespace private var selectionAnimation
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage("animationsEnabled", store: MountainExperience.defaults) private var animationsEnabled = true
    private var reduceMotion: Bool { systemReduceMotion || !animationsEnabled }
    @ScaledMetric(relativeTo: .title3) private var numberSize: CGFloat = 20
    @ScaledMetric(relativeTo: .caption) private var badgeSize: CGFloat = 12
    private var compact: Bool {
#if os(iOS)
        horizontalSizeClass != .regular && availableWidth < 600 && !fitAllSizes
#else
        false
#endif
    }
    /// Desktop tiles are large, so their numbers fill more of the square.
    private func numeralSize(_ width: CGFloat) -> CGFloat {
#if os(macOS)
        let base = max(numberSize * numberScale, width * 0.36)
#else
        let base = numberSize * numberScale
#endif
        return min(base, max(1, (width - 4) / 2.2))
    }
    /// The player who made the last move; `play` always hands the turn on.
    private var mover: Int { 1 - game.turn }
    var body: some View {
        let metrics = MountainBoardLayout(size: game.size, availableWidth: Double(availableWidth), availableHeight: availableHeight.map(Double.init), compact: compact, scrollThreshold: scrollThreshold, minimumTile: Double(minimumTile))
        Group {
            if metrics.scrolls {
                ScrollView(.horizontal) { grid(metrics) }
                    .accessibilityIdentifier("board-scroll")
            } else {
                grid(metrics)
            }
        }
        .frame(width: max(64, availableWidth))
        .background(MountainStyle.ink.opacity(0.7), in: RoundedRectangle(cornerRadius: 20))
    }
    private func grid(_ metrics: MountainBoardLayout) -> some View {
        let width = CGFloat(metrics.tile)
        return LazyVGrid(columns: Array(repeating: GridItem(.fixed(width), spacing: MountainBoardLayout.gap), count: game.size), spacing: MountainBoardLayout.gap) {
                ForEach(game.tiles) { tile in
                    let playable = game.canPlay(tile.id)
                    Button { select(tile.id) } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(tile.value == 0 ? MountainStyle.cream.opacity(0.035) : playable ? MountainStyle.player(game.turn) : MountainStyle.cream)
                                .overlay { MountainTileValueShading(value: tile.value, playable: playable, player: game.turn) }
                            if tile.value == 0 {
                                if lastMove == tile.id {
                                    MountainDrainingNumber(points: lastPoints, from: numeralSize(width), to: min(badgeSize, max(1, (width - 4) / 2.8)), reduceMotion: reduceMotion)
                                        .transition(.identity)
                                } else {
                                    Image(systemName: "leaf.fill").font(.caption).foregroundStyle(MountainStyle.cream.opacity(0.22))
                                        .transition(.identity).transaction { $0.animation = nil }
                                }
                            } else {
                                Text("\(tile.value)").font(.system(size: numeralSize(width), weight: .heavy)).monospacedDigit()
                                    .lineLimit(1).minimumScaleFactor(0.1).padding(.horizontal, 2).foregroundStyle(MountainStyle.ink)
                                    .transition(.identity).transaction { $0.animation = nil }
                            }
                        }.frame(width: width, height: width)
                            .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(playable ? MountainStyle.cream.opacity(0.75) : .clear, lineWidth: 2)
                                // A taken tile was the last mover's; an open one is the current player's pending pick.
                                if selected == tile.id { RoundedRectangle(cornerRadius: 12).strokeBorder(MountainStyle.player(tile.value == 0 ? mover : game.turn), lineWidth: 5) }
                                if lastMove == tile.id {
                                    RoundedRectangle(cornerRadius: 12).strokeBorder(MountainStyle.player(mover), lineWidth: 3)
                                        .matchedGeometryEffect(id: "last-picked-square", in: selectionAnimation)
                                }
                            }
                            .shadow(color: .black.opacity(tile.value == 0 ? 0 : 0.2), radius: 3, x: 0, y: 3)
                    }
                    .anchorPreference(key: MountainMoveAnchors.self, value: .bounds) { [.tile(tile.id): $0] }
                    .phaseAnimator([false, true, false], trigger: lastMove) { content, pulse in
                        content.scaleEffect(!reduceMotion && lastMove == tile.id && pulse ? 1.08 : 1)
                    }
                    .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.7), value: lastMove)
                    .buttonStyle(MountainTileButton()).mountainHover().disabled(!playable || !interactive || game.isOver)
                    .accessibilityLabel(tile.value == 0 ? String(localized: "Row \(tile.id / game.size + 1), column \(tile.id % game.size + 1), used") : String(localized: "Row \(tile.id / game.size + 1), column \(tile.id % game.size + 1), \(tile.value) points"))
                    .accessibilityHint(!playable ? "" : game.turn == 0 ? String(localized: "Adds \(tile.value) points and sets the next player's column") : String(localized: "Adds \(tile.value) points and sets the next player's row"))
                    .accessibilityIdentifier("tile-\(tile.id)")
                }
        }.padding(MountainBoardLayout.padding).frame(width: CGFloat(metrics.extent))
            .accessibilityElement(children: .contain).accessibilityIdentifier("game-board")
    }
}


extension View {
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
    @ViewBuilder func mountainGameFeedback(moves: Int, over: Bool, enabled: Bool = true, intensity: Double = 0.5) -> some View {
#if os(iOS)
        sensoryFeedback(.impact(weight: .medium, intensity: min(1, max(0, intensity))), trigger: moves) { old, new in enabled && !MountainExperience.isQAActive && new > old }
            .sensoryFeedback(.success, trigger: over) { _, finished in enabled && !MountainExperience.isQAActive && finished }
#else
        self
#endif
    }
}

enum MountainMoveAnchor: Hashable { case tile(Int), score(Int) }
struct MountainMoveAnchors: PreferenceKey {
    static var defaultValue: [MountainMoveAnchor: Anchor<CGRect>] = [:]
    static func reduce(value: inout [MountainMoveAnchor: Anchor<CGRect>], nextValue: () -> [MountainMoveAnchor: Anchor<CGRect>]) { value.merge(nextValue(), uniquingKeysWith: { _, new in new }) }
}

/// A hidden text template alone determines geometry; changing content is painted in its overlay.
struct MountainReservedText<Content: View>: View {
    var lines = 1
    var alignment: Alignment = .leading
    @ViewBuilder var content: Content
    var body: some View {
        Text(Array(repeating: "Ag", count: lines).joined(separator: "\n"))
            .fixedSize(horizontal: false, vertical: true).hidden().accessibilityHidden(true)
            .frame(maxWidth: .infinity, alignment: alignment)
            .overlay(alignment: alignment) { content.lineLimit(lines).minimumScaleFactor(0.5) }
    }
}

struct MountainMoveEffects: View {
    @Binding var events: [MountainMoveFeedback]
    let anchors: [MountainMoveAnchor: Anchor<CGRect>]
    var reduceMotion: Bool
    @AppStorage("computerMoveDuration", store: MountainExperience.defaults) private var pace = 0.7
    private var duration: Double { MountainMoveFeedback.duration * (pace.isFinite ? min(1.2, max(0.4, pace)) : 0.7) / 0.7 }
    var body: some View {
        GeometryReader { proxy in
            if !reduceMotion {
                ForEach(events, id: \.token) { event in
                    ZStack {
                        Color.clear // Keep expiry mounted even when a scrolled-off tile has no anchor.
                        if let source = anchors[.tile(event.tile)], let target = anchors[.score(event.player)] {
                            MountainMoveVisual(event: event, duration: duration,
                                start: CGPoint(x: proxy[source].midX, y: proxy[source].midY),
                                end: CGPoint(x: proxy[target].midX, y: proxy[target].midY))
                        }
                    }.task {
                        do { try await Task.sleep(for: .seconds(duration + 0.1)) } catch { return }
                        guard !Task.isCancelled else { return }
                        events = MountainMoveFeedback.finishing(event.token, in: events)
                    }
                }
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct MountainMoveVisual: View {
    let duration: Double
    let event: MountainMoveFeedback
    @State private var start: CGPoint
    @State private var end: CGPoint
    @State private var progress = 0.0
    init(event: MountainMoveFeedback, duration: Double, start: CGPoint, end: CGPoint) {
        self.event = event; self.duration = duration
        // Capture endpoints once: animated score digit widths cannot bend an in-flight path.
        _start = State(initialValue: start); _end = State(initialValue: end)
    }
    var body: some View {
        MountainMoveFlight(event: event, start: start, end: end, progress: progress)
            .onAppear { withAnimation(.linear(duration: duration)) { progress = 1 } }
    }
}

struct MountainMoveFlight: View, Animatable {
    let event: MountainMoveFeedback
    let start: CGPoint
    let end: CGPoint
    var progress: Double
    var animatableData: Double { get { progress } set { progress = newValue } }
    var body: some View {
        ZStack {
            Canvas { context, _ in
                for index in 0..<event.particleCount {
                    let point = MountainPointParticle.sample(index: index, count: event.particleCount, progress: progress,
                        startX: start.x, startY: start.y, endX: end.x, endY: end.y, spread: event.spread)
                    // Flower petals: each tumbles at its own rate on the way to the score.
                    let radius = 2.5 + event.intensity * 1.5
                    var petal = context
                    petal.translateBy(x: point.x, y: point.y)
                    petal.rotate(by: .radians(Double(index) * 2.39996 + progress * .pi * (3 + Double(index % 3))))
                    let shape = Path(ellipseIn: CGRect(x: -radius * 0.7, y: -radius * 1.5, width: radius * 1.4, height: radius * 3))
                    petal.opacity = point.opacity * 0.2
                    petal.fill(shape.applying(.init(scaleX: 1.8, y: 1.4)), with: .color(MountainStyle.player(event.player)))
                    petal.opacity = point.opacity
                    petal.fill(shape, with: .color(MountainStyle.player(event.player)))
                    petal.fill(Path(ellipseIn: CGRect(x: -radius * 0.2, y: radius * 0.6, width: radius * 0.4, height: radius * 0.8)), with: .color(MountainStyle.cream.opacity(0.7)))
                }
            }

        }
    }
}

struct MountainScoreNumber: View, Animatable {
    var value: Double
    var animatableData: Double { get { value } set { value = newValue } }
    var body: some View { Text("\(Int(value.rounded()))").monospacedDigit() }
}

/// The connected display is a presentation surface; this view cannot play a move or create an AI task.
struct MountainExternalPresentation: View {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage("animationsEnabled", store: MountainExperience.defaults) private var animationsEnabled = true
    private var reduceMotion: Bool { systemReduceMotion || !animationsEnabled }
    @State private var feedback: [MountainMoveFeedback] = []
    let snapshot: MountainDisplaySnapshot
    var body: some View {
        GeometryReader { geometry in
            let inset = max(20, min(geometry.size.width, geometry.size.height) * 0.045)
            let scoreWidth = min(360, max(180, geometry.size.width * 0.25))
            let wide = geometry.size.width > geometry.size.height
            let side = max(120, min(geometry.size.height - inset * 2 - (wide ? 0 : 220), geometry.size.width - inset * 2 - (wide ? scoreWidth + 36 : 0)))
            ZStack {
                MountainScenery(active: !snapshot.paused, celebration: snapshot.humanVictory)
                    .overlay(MountainStyle.ink.opacity(0.50)).ignoresSafeArea()
                VStack(spacing: 24) {
                    if wide {
                        HStack(alignment: .center, spacing: 36) {
                            displayBoard(side: side).frame(maxWidth: .infinity)
                            VStack(spacing: 24) { displayScore(0, height: geometry.size.height); displayScore(1, height: geometry.size.height) }.frame(width: scoreWidth)
                        }
                    } else {
                        displayBoard(side: side)
                        HStack(spacing: 24) { displayScore(0, height: geometry.size.height * 0.5); displayScore(1, height: geometry.size.height * 0.5) }
                    }
                    Spacer(minLength: 0)
                }.padding(inset)
                if snapshot.game.isOver {
                    VStack(spacing: 18) {
                        Image(systemName: snapshot.humanVictory ? "crown.fill" : "leaf.fill").font(.system(size: 56)).accessibilityHidden(true)
                        Text(snapshot.game.scores[0] == snapshot.game.scores[1] ? String(localized: "An even tangle") : String(localized: "\(snapshot.names[snapshot.game.scores[0] > snapshot.game.scores[1] ? 0 : 1]) wins!"))
                            .font(MountainStyle.display(54)).multilineTextAlignment(.center)
                        Text("\(snapshot.game.scores[0]) : \(snapshot.game.scores[1])").font(.largeTitle.bold()).monospacedDigit()
                    }.padding(48).background(MountainStyle.ink.opacity(0.96), in: RoundedRectangle(cornerRadius: 32))
                        .overlay { RoundedRectangle(cornerRadius: 32).strokeBorder(MountainStyle.gold.opacity(0.7), lineWidth: 2) }
                        .padding(inset)
                }
            }.onChange(of: geometry.size) { _, _ in feedback.removeAll() }
        }
        .overlayPreferenceValue(MountainMoveAnchors.self) { anchors in
            MountainMoveEffects(events: $feedback, anchors: anchors, reduceMotion: reduceMotion)
        }
        .onChange(of: snapshot.game.moves) { old, new in
            guard new > old, !reduceMotion, !snapshot.paused, let tile = snapshot.lastMove else { return }
            let event = MountainMoveFeedback(id: new, tile: tile, player: 1 - snapshot.game.turn, points: snapshot.lastPoints, maximum: snapshot.game.size * snapshot.game.size)
            feedback = event.adding(to: feedback)
        }
        .onChange(of: snapshot.paused) { _, paused in if paused { feedback.removeAll() } }
        .onChange(of: reduceMotion) { _, reduced in if reduced { feedback.removeAll() } }
        .foregroundStyle(MountainStyle.cream).preferredColorScheme(.dark)
    }
    private func displayBoard(side: CGFloat) -> some View {
        MountainBoard(game: snapshot.game, availableWidth: side, fitAllSizes: true, numberScale: 2,
                      lastMove: snapshot.lastMove, lastPoints: snapshot.lastPoints)
            .allowsHitTesting(false)
    }
    @ViewBuilder private func displayAvatar(_ player: Int, size: CGFloat) -> some View {
        let style = snapshot.avatarStyles.indices.contains(player) ? snapshot.avatarStyles[player] : "fonster"
        if snapshot.computers[player] {
            MountainRivalFace(difficulty: snapshot.rival(player), twin: player == 0 && snapshot.computers[1] && snapshot.rival(0) == snapshot.rival(1), size: size)
                .frame(width: size, height: size).clipShape(Circle()).accessibilityHidden(true)
        } else {
            MountainAvatar(name: snapshot.names[player], symbol: snapshot.symbols[player], style: style,
                           photoID: snapshot.photoIDs.indices.contains(player) ? snapshot.photoIDs[player] : nil, size: size,
                           activity: .init(game: snapshot.game, player: player, paused: snapshot.paused, lastMove: snapshot.lastMove))
        }
    }
    private func displayScore(_ player: Int, height: CGFloat) -> some View {
        let compact = height < 600
        return VStack(alignment: .leading, spacing: compact ? 8 : 16) {
            HStack(spacing: compact ? 8 : 14) {
                displayAvatar(player, size: compact ? 48 : 72)
                MountainReservedText(lines: 2) { Text(snapshot.names[player]) }.font(compact ? .headline : .title.weight(.semibold))
            }
            MountainReservedText {
                MountainScoreNumber(value: Double(snapshot.game.scores[player]))
                .font(MountainStyle.display(max(32, min(108, height * (compact ? 0.1 : 0.14)))))
                .lineLimit(1).minimumScaleFactor(0.25)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: snapshot.game.scores[player])
                .anchorPreference(key: MountainMoveAnchors.self, value: .bounds) { [.score(player): $0] }
            }.font(MountainStyle.display(max(32, min(108, height * (compact ? 0.1 : 0.14)))))
        }.padding(compact ? 16 : 28).frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(MountainStyle.player(player))
            .background(MountainStyle.ink.opacity(0.80), in: RoundedRectangle(cornerRadius: 24))
            .overlay { MountainPlayerHighlight(player: player, active: snapshot.game.turn == player && !snapshot.game.isOver) }
            .accessibilityElement(children: .ignore).accessibilityLabel(MountainSpeech.player(snapshot.names[player], points: snapshot.game.scores[player], seat: player) + " " + (snapshot.game.isOver ? String(localized: "Game over") : snapshot.game.turn == player ? String(localized: "Your turn") : String(localized: "Waiting")))
    }
}

/// Spoken score-card phrases built from whole localized sentences.
enum MountainSpeech {
    static func player(_ name: String, points: Int, seat: Int) -> String {
        seat == 0 ? String(localized: "\(name), \(points) points. Row player.") : String(localized: "\(name), \(points) points. Column player.")
    }
}

/// The picked number counts down and shrinks as its points fly to the score, ending as "+points".
private struct MountainDrainingNumber: View {
    let points: Int
    let from: CGFloat
    let to: CGFloat
    let reduceMotion: Bool
    @AppStorage("computerMoveDuration", store: MountainExperience.defaults) private var pace = 0.7
    @State private var progress = 0.0
    var body: some View {
        MountainDrainingFrame(points: points, from: from, to: to, progress: reduceMotion ? 1 : progress)
            .onAppear {
                guard !reduceMotion else { return }
                let duration = MountainMoveFeedback.duration * (pace.isFinite ? min(1.2, max(0.4, pace)) : 0.7) / 0.7
                withAnimation(.easeInOut(duration: duration)) { progress = 1 }
            }
    }
}
private struct MountainDrainingFrame: View, Animatable {
    let points: Int
    let from: CGFloat
    let to: CGFloat
    var progress: Double
    var animatableData: Double { get { progress } set { progress = newValue } }
    var body: some View {
        let done = progress >= 1
        let remaining = Int((Double(points) * (1 - progress)).rounded())
        Text(done ? "+\(points)" : "\(remaining)")
            .font(.system(size: max(1, from + (to - from) * progress), weight: done ? .bold : .heavy)).monospacedDigit()
            .lineLimit(1).minimumScaleFactor(0.1).padding(.horizontal, 2)
            .foregroundStyle(MountainStyle.cream)
    }
}

/// A rival's painted portrait. Rivals without a painting, and the second copy of a rival
/// playing itself, show a lettered leaf badge so the two seats never look identical.
struct MountainRivalFace: View {
    let difficulty: ComputerDifficulty
    var twin = false
    var size: CGFloat = 48
    var body: some View {
        if let portrait = difficulty.portrait, !twin {
            Image(portrait).resizable().scaledToFill()
        } else {
            ZStack {
                Circle().fill(twin ? MountainStyle.mint : MountainStyle.gold)
                Image(systemName: "leaf.fill").resizable().scaledToFit().padding(size * 0.14)
                    .foregroundStyle(MountainStyle.ink.opacity(0.18)).rotationEffect(.degrees(-30))
                Text(verbatim: String(difficulty.name.prefix(1))).font(.custom("Georgia-Bold", size: size * 0.52)).foregroundStyle(MountainStyle.ink)
            }
        }
    }
}
