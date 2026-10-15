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
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.9 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
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
                            if tile.value == 0 {
                                if lastMove == tile.id {
                                    Text("+\(lastPoints)").font(.system(size: min(badgeSize, max(1, (width - 4) / 2.8)), weight: .bold)).lineLimit(1).minimumScaleFactor(0.1).foregroundStyle(MountainStyle.cream)
                                        .transition(.identity).transaction { $0.animation = nil }
                                } else {
                                    Image(systemName: "pawprint.fill").font(.caption).foregroundStyle(MountainStyle.cream.opacity(0.22))
                                        .transition(.identity).transaction { $0.animation = nil }
                                }
                            } else {
                                Text("\(tile.value)").font(.system(size: min(numberSize * numberScale, max(1, (width - 4) / 2.2)), weight: .heavy)).monospacedDigit()
                                    .lineLimit(1).minimumScaleFactor(0.1).padding(.horizontal, 2).foregroundStyle(MountainStyle.ink)
                                    .transition(.identity).transaction { $0.animation = nil }
                            }
                        }.frame(width: width, height: width)
                            .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(playable ? MountainStyle.cream.opacity(0.75) : .clear, lineWidth: 2)
                                if selected == tile.id { RoundedRectangle(cornerRadius: 12).strokeBorder(MountainStyle.gold, lineWidth: 5) }
                                if lastMove == tile.id {
                                    RoundedRectangle(cornerRadius: 12).strokeBorder(MountainStyle.gold, lineWidth: 3)
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
                    .accessibilityLabel("Row \(tile.id / game.size + 1), column \(tile.id % game.size + 1), \(tile.value == 0 ? "used" : String(tile.value))")
                    .accessibilityHint(playable ? "Adds \(tile.value) points and sets the next player's \(game.turn == 0 ? "column" : "row")" : "")
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
                    let radius = 2.5 + event.intensity * 1.5
                    let core = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
                    context.opacity = point.opacity * 0.18
                    context.fill(Path(ellipseIn: core.insetBy(dx: -radius, dy: -radius)), with: .color(MountainStyle.player(event.player)))
                    context.opacity = point.opacity
                    context.fill(Path(ellipseIn: core), with: .color(MountainStyle.player(event.player)))
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
    @AppStorage("aiUsesPictures", store: MountainExperience.defaults) private var pictures = false
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
                        Image(systemName: snapshot.humanVictory ? "pawprint.fill" : "mountain.2.fill").font(.system(size: 56)).accessibilityHidden(true)
                        Text(snapshot.game.scores[0] == snapshot.game.scores[1] ? "An even climb" : "\(snapshot.names[snapshot.game.scores[0] > snapshot.game.scores[1] ? 0 : 1]) wins!")
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
        if snapshot.computers[player] && pictures && style == "fonster" {
            Image(snapshot.difficulty.portrait).resizable().scaledToFill().frame(width: size, height: size).clipShape(Circle()).accessibilityHidden(true)
        } else {
            MountainAvatar(name: snapshot.computers[player] ? snapshot.difficulty.name : snapshot.names[player], symbol: snapshot.symbols[player], style: style,
                           photoID: snapshot.photoIDs.indices.contains(player) ? snapshot.photoIDs[player] : nil, size: size)
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
            .accessibilityElement(children: .ignore).accessibilityLabel("\(snapshot.names[player]), \(snapshot.game.scores[player]) points. \(player == 0 ? "Row" : "Column") player. \(snapshot.game.isOver ? "Game over" : snapshot.game.turn == player ? "Your turn" : "Waiting")")
    }
}
