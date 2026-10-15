import SwiftUI

struct MountainButton: ButtonStyle {
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


struct MountainBoard: View {
    let game: MountainGame
    let availableWidth: CGFloat
    var availableHeight: CGFloat? = nil
    var fitAllSizes = false
    @AppStorage("boardScrollThreshold") private var scrollThreshold = 7
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                                } else {
                                    Image(systemName: "pawprint.fill").font(.caption).foregroundStyle(MountainStyle.cream.opacity(0.22))
                                }
                            } else {
                                Text("\(tile.value)").font(.system(size: min(numberSize, max(1, (width - 4) / 2.2)), weight: .heavy)).monospacedDigit()
                                    .lineLimit(1).minimumScaleFactor(0.1).padding(.horizontal, 2).foregroundStyle(MountainStyle.ink)
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
            .accessibilityIdentifier("game-board")
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
        sensoryFeedback(.impact(weight: .medium, intensity: min(1, max(0, intensity))), trigger: moves) { old, new in enabled && new > old }
            .sensoryFeedback(.success, trigger: over) { _, finished in enabled && finished }
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

struct MountainMoveVisual: View {
    let event: MountainMoveFeedback
    let start: CGPoint
    let end: CGPoint
    @State private var progress = 0.0
    var body: some View {
        MountainMoveFlight(event: event, start: start, end: end, progress: progress)
            .onAppear { withAnimation(.easeInOut(duration: 0.55)) { progress = 1 } }
    }
}

private struct MountainMoveFlight: View, Animatable {
    let event: MountainMoveFeedback
    let start: CGPoint
    let end: CGPoint
    var progress: Double
    var animatableData: Double { get { progress } set { progress = newValue } }
    var body: some View {
        ZStack {
            ForEach(0..<(4 + Int(event.intensity * 8)), id: \.self) { index in
                let angle = Double(index) * 2.39996
                let distance = (12 + event.intensity * 32) * progress
                Circle().fill(MountainStyle.player(event.player))
                    .frame(width: 2 + event.intensity * 3, height: 2 + event.intensity * 3)
                    .position(x: start.x + cos(angle) * distance, y: start.y + sin(angle) * distance + 16 * progress * progress)
                    .opacity(max(0, 1 - progress * 1.7))
            }
            Text("+\(event.points)").font(.title2.bold()).monospacedDigit()
                .foregroundStyle(MountainStyle.player(event.player))
                .padding(8).background(MountainStyle.ink, in: Capsule())
                .scaleEffect(1 + event.intensity * 0.2 * sin(progress * .pi))
                .position(x: start.x + (end.x - start.x) * progress,
                          y: start.y + (end.y - start.y) * progress - sin(progress * .pi) * 44)
                .opacity(progress < 0.85 ? 1 : max(0, (1 - progress) / 0.15))
        }
    }
}

struct MountainScoreNumber: View, Animatable {
    var value: Double
    var animatableData: Double { get { value } set { value = newValue } }
    var body: some View { Text("\(Int(value.rounded()))").monospacedDigit() }
}
