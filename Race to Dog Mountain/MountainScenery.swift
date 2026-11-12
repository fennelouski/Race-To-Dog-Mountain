import SwiftUI
import CoreText

enum MountainStyle {
#if os(visionOS)
    static let headerControlSize: CGFloat = 60
#else
    static let headerControlSize: CGFloat = 48
#endif
    static let ink = Color(red: 0.025, green: 0.12, blue: 0.17)
    static let cream = Color(red: 1, green: 0.95, blue: 0.82)
    static let gold = Color(red: 1, green: 0.73, blue: 0.28)
    static let mint = Color(red: 0.42, green: 0.88, blue: 0.81)
    /// Light enough for ink numerals; gold and mint stay the defaults.
    static let palette: [(name: String, red: Double, green: Double, blue: Double)] = [
        (String(localized: "Gold"), 1, 0.73, 0.28), (String(localized: "Mint"), 0.42, 0.88, 0.81), (String(localized: "Coral"), 1, 0.5, 0.45), (String(localized: "Rose"), 1, 0.58, 0.72),
        (String(localized: "Lavender"), 0.74, 0.62, 1), (String(localized: "Sky"), 0.45, 0.75, 1), (String(localized: "Lime"), 0.72, 0.9, 0.35), (String(localized: "Tangerine"), 1, 0.6, 0.2),
        (String(localized: "Lemon"), 1, 0.88, 0.3), (String(localized: "Seafoam"), 0.5, 0.95, 0.65), (String(localized: "Peach"), 1, 0.72, 0.56), (String(localized: "Lilac"), 0.85, 0.62, 0.95),
        (String(localized: "Periwinkle"), 0.6, 0.68, 1), (String(localized: "Aqua"), 0.3, 0.85, 0.95), (String(localized: "Leaf"), 0.5, 0.82, 0.4), (String(localized: "Berry"), 0.95, 0.45, 0.6),
        (String(localized: "Orchid"), 0.9, 0.52, 0.86), (String(localized: "Ice"), 0.68, 0.9, 1), (String(localized: "Pistachio"), 0.78, 0.92, 0.6), (String(localized: "Cherry"), 0.98, 0.38, 0.42)
    ]
    static func colorKey(_ player: Int) -> String { "player\(player + 1)Color" }
    static func colorIndex(_ player: Int) -> Int {
        let stored = MountainExperience.defaults.object(forKey: colorKey(player)) as? Int ?? player
        return palette.indices.contains(stored) ? stored : min(1, max(0, player))
    }
    static func swatch(_ index: Int) -> Color { let c = palette[index]; return Color(red: c.red, green: c.green, blue: c.blue) }
    static func player(_ index: Int) -> Color { swatch(colorIndex(index)) }
    /// Darker edge tint for a player's playable tiles.
    static func shade(_ player: Int) -> Color {
        switch colorIndex(player) {
        case 0: Color(red: 0.82, green: 0.34, blue: 0.04)
        case 1: Color(red: 0.04, green: 0.44, blue: 0.40)
        case let i: Color(red: palette[i].red * 0.5, green: palette[i].green * 0.5, blue: palette[i].blue * 0.5)
        }
    }
    static func display(_ size: CGFloat) -> Font {
        .custom("Georgia-Bold", size: size, relativeTo: .largeTitle)
    }
}

/// The tint is clipped inside the tile; intersecting edge fades leave its center
/// transparent. Apply behind the numeral and below selection/turn outlines.
struct MountainTileValueShading: View {
    let value: Int
    var playable = false
    var player = 0
    var cornerRadius: CGFloat = 12
    private var tint: Color {
        guard playable else { return MountainStyle.gold }
        return MountainStyle.shade(player)
    }
    var body: some View {
        if value > 0 {
            tint.opacity(MountainTileIntensity.edgeOpacity(for: value))
                .mask {
                    ZStack {
                        LinearGradient(colors: [.white, .clear, .white], startPoint: .top, endPoint: .bottom)
                        LinearGradient(colors: [.white, .clear, .white], startPoint: .leading, endPoint: .trailing)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .allowsHitTesting(false).accessibilityHidden(true)
        }
    }
}

/// Only the scenery redraws. Game state and controls do not tick with the sky.
struct MountainScenery: View {
    var active = true
    var celebration = false
    var followsLocalTime = false
    /// The home screen's denser canopy: more, longer vines with blossoms and drifting fireflies.
    var lush = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage("animationsEnabled", store: MountainExperience.defaults) private var animationsEnabled = true
    private var reduceMotion: Bool { systemReduceMotion || !animationsEnabled }
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion || !active || scenePhase != .active)) { timeline in
            Canvas { context, size in
                let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                let w = size.width, h = size.height
                let sky = followsLocalTime ? MountainSky(date: timeline.date) : nil
                let day = sky?.daylight ?? 0
                func blended(_ night: (Double, Double, Double), _ dayColor: (Double, Double, Double)) -> Color {
                    Color(red: night.0 + (dayColor.0 - night.0) * day, green: night.1 + (dayColor.1 - night.1) * day, blue: night.2 + (dayColor.2 - night.2) * day)
                }
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
                    Gradient(colors: [blended((0.025, 0.12, 0.17), (0.12, 0.40, 0.58)), blended((0.08, 0.32, 0.36), (0.37, 0.65, 0.68)), blended((0.32, 0.57, 0.53), (0.75, 0.76, 0.58))]),
                    startPoint: .zero, endPoint: CGPoint(x: w * 0.8, y: h)))
                let progress = sky?.sunProgress ?? 0.6
                let diameter = w * (sky == nil ? 0.30 : 0.22)
                let sun = CGRect(x: w * (sky == nil ? 0.62 : -0.08 + 1.16 * progress) - diameter / 2,
                                 y: h * (sky == nil ? 0.42 : 0.64 - sin(progress * .pi) * 0.42), width: diameter, height: diameter)
                if day > 0 || sky == nil {
                    context.fill(Path(ellipseIn: sun.insetBy(dx: -18, dy: -18)), with: .color(MountainStyle.gold.opacity(0.06 * (sky == nil ? 1 : day))))
                    context.fill(Path(ellipseIn: sun), with: .color(MountainStyle.gold.opacity(sky == nil ? 1 : day)))
                }
                if sky != nil && day < 1 {
                    let moon = CGRect(x: w * 0.72, y: h * 0.25, width: w * 0.16, height: w * 0.16)
                    context.fill(Path(ellipseIn: moon), with: .color(MountainStyle.cream.opacity((1 - day) * 0.65)))
                    context.fill(Path(ellipseIn: moon.offsetBy(dx: -w * 0.04, dy: -w * 0.02)), with: .color(blended((0.04, 0.18, 0.23), (0.18, 0.46, 0.59))))
                }
                for i in 0..<5 {
                    let drift = sin(time * 0.06 + Double(i)) * w * 0.08
                    let x = CGFloat(i) * w * 0.3 - w * 0.2 + drift
                    let y = h * (0.40 + CGFloat(i % 3) * 0.08)
                    let cloud = CGRect(x: x, y: y, width: w * 0.38, height: 2 + CGFloat(i % 2) * 3)
                    context.fill(Path(roundedRect: cloud, cornerRadius: 3), with: .color(MountainStyle.cream.opacity(0.15)))
                }
                // Leafy hedges: each layer is a run of overlapping leaf clumps on a gentle baseline.
                let hedges: [(base: Double, wave: Double, radius: Double, color: Color)] = [
                    (0.62, 0.05, 0.075, Color(red: 0.22, green: 0.49, blue: 0.40)),
                    (0.72, 0.04, 0.065, Color(red: 0.10, green: 0.34, blue: 0.27)),
                    (0.82, 0.03, 0.055, MountainStyle.ink)
                ]
                for (layer, hedge) in hedges.enumerated() {
                    var path = Path()
                    let r = hedge.radius * w, step = r * 1.3
                    var x = -r
                    while x < w + r {
                        let u = Double(x / w)
                        let y = h * (hedge.base + sin(u * 5 + Double(layer) * 2) * hedge.wave)
                        let size = r * (0.8 + 0.4 * (sin(u * 31 + Double(layer)) + 1) / 2)
                        path.addEllipse(in: CGRect(x: x - size, y: y - size, width: size * 2, height: size * 2))
                        x += step
                    }
                    path.addRect(CGRect(x: 0, y: h * hedge.base, width: w, height: h * (1 - hedge.base)))
                    context.fill(path, with: .color(hedge.color))
                }
                // Tangled vines hang from the canopy; neighbours cross as they sway.
                let stem = Color(red: 0.18, green: 0.48, blue: 0.27), leafColor = Color(red: 0.42, green: 0.74, blue: 0.36)
                let vineCount = lush ? 14 : 7
                for vine in 0..<vineCount {
                    let anchor = (Double(vine) + 0.5) / Double(vineCount) + (lush ? sin(Double(vine) * 2.7) * 0.02 : 0)
                    let length = h * (lush ? 0.10 + Double((vine * 37) % 7) * 0.045 : 0.09 + Double((vine * 37) % 5) * 0.035)
                    let sway = sin(time * (lush ? 0.4 + Double(vine % 3) * 0.12 : 0.5) + Double(vine) * 1.3) * w * (lush ? 0.03 : 0.02)
                    let samples = 28
                    func point(_ t: Double) -> CGPoint {
                        let curl = sin(t * 7 + Double(vine) * 2.1) * w * 0.035 * t
                        return CGPoint(x: anchor * w + curl + sway * t, y: -4 + t * length)
                    }
                    var path = Path(); path.move(to: point(0))
                    for i in 1...samples { path.addLine(to: point(Double(i) / Double(samples))) }
                    context.stroke(path, with: .color(stem.opacity(0.9)), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    for i in stride(from: 3, through: samples, by: 3) {
                        let p = point(Double(i) / Double(samples)), q = point(Double(i + 1) / Double(samples))
                        var leaf = context
                        leaf.translateBy(x: p.x, y: p.y)
                        leaf.rotate(by: .radians(atan2(q.y - p.y, q.x - p.x) + (i % 6 == 0 ? 0.9 : -0.9)))
                        leaf.fill(Path(ellipseIn: CGRect(x: 0, y: -3.5, width: 14, height: 7)), with: .color(leafColor.opacity(0.9)))
                    }
                    if lush && vine % 3 != 1 {
                        // A blossom at the tip that gently opens and closes.
                        let tip = point(1), open = 4.5 + sin(time * 0.9 + Double(vine)) * 1.2
                        let petal = [Color(red: 1, green: 0.58, blue: 0.72), MountainStyle.gold, Color(red: 0.74, green: 0.62, blue: 1)][vine % 3]
                        for k in 0..<5 {
                            let angle = Double(k) * 2 * .pi / 5 + time * 0.2
                            context.fill(Path(ellipseIn: CGRect(x: tip.x + cos(angle) * open - 3.5, y: tip.y + sin(angle) * open - 3.5, width: 7, height: 7)), with: .color(petal))
                        }
                        context.fill(Path(ellipseIn: CGRect(x: tip.x - 2.5, y: tip.y - 2.5, width: 5, height: 5)), with: .color(MountainStyle.cream))
                    }
                }
                if lush {
                    // Fireflies wander through the middle of the screen.
                    for i in 0..<12 {
                        let seed = Double(i) * 1.618
                        let x = w * (0.1 + 0.8 * ((seed * 0.37).truncatingRemainder(dividingBy: 1))) + sin(time * 0.3 + seed * 3) * w * 0.06
                        let y = h * (0.25 + 0.5 * ((seed * 0.61).truncatingRemainder(dividingBy: 1))) + cos(time * 0.25 + seed * 2) * h * 0.04
                        let glow = 0.25 + (sin(time * 1.4 + seed * 5) + 1) * 0.3
                        context.fill(Path(ellipseIn: CGRect(x: x - 6, y: y - 6, width: 12, height: 12)), with: .color(MountainStyle.gold.opacity(glow * 0.18)))
                        context.fill(Path(ellipseIn: CGRect(x: x - 2, y: y - 2, width: 4, height: 4)), with: .color(Color(red: 1, green: 0.9, blue: 0.6).opacity(glow)))
                    }
                }
                // A curling gold tendril, echoed by the game's row/column path.
                var tendril = Path()
                tendril.addArc(center: CGPoint(x: w * 0.66, y: h * 0.70), radius: w * 0.04, startAngle: .degrees(-90), endAngle: .degrees(180), clockwise: false)
                tendril.addCurve(to: CGPoint(x: w * 0.43, y: h), control1: CGPoint(x: w * 0.2, y: h * 0.82), control2: CGPoint(x: w * 0.95, y: h * 0.90))
                context.stroke(tendril, with: .color(MountainStyle.gold.opacity(0.18)), style: StrokeStyle(lineWidth: 2, dash: [4, 9], dashPhase: reduceMotion ? 0 : -time * 3))
                for i in 0..<30 {
                    let x = (CGFloat((i * 73 + 17) % 307) / 307) * w
                    let y = (CGFloat((i * 47 + 11) % 271) / 271) * h * 0.65
                    let opacity = 0.18 + (sin(time * 0.6 + Double(i)) + 1) * 0.18
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: i % 4 == 0 ? 3 : 1.5, height: i % 4 == 0 ? 3 : 1.5)), with: .color(MountainStyle.cream.opacity(opacity * (1 - day))))
                }
                if celebration {
                    for i in 0..<36 {
                        let phase = (time * 0.12 + Double(i) / 36).truncatingRemainder(dividingBy: 1)
                        let x = CGFloat((i * 83) % 347) / 347 * w
                        let y = reduceMotion ? CGFloat(i % 8) * h / 8 : phase * h
                        // Falling leaves that tumble as they drift down.
                        var leaf = context
                        leaf.translateBy(x: x + sin(time * 1.3 + Double(i)) * 14, y: y)
                        leaf.rotate(by: .radians(time * (1 + Double(i % 3) * 0.4) + Double(i)))
                        leaf.fill(Path(ellipseIn: CGRect(x: -3, y: -6, width: 6, height: 12)), with: .color(MountainStyle.player(i % 2).opacity(0.7)))
                    }
                }
            }
        }
        .ignoresSafeArea().allowsHitTesting(false).accessibilityHidden(true)
    }
}

/// Tangled vines grow across the view, then unwind from their roots. Rows and
/// columns of vines echo the board. Purely decorative and never hit-testable.
struct MountainVineSweep: View {
    var trigger = 0
    /// Covers what's behind until the vines unwind (used at launch).
    var curtain = false
    /// Dense enough to hide everything underneath at the halfway point, then recedes.
    var cover = false
    var duration = 1.4
    var onFinish: () -> Void = {}
    @State private var progress = 1.0
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage("animationsEnabled", store: MountainExperience.defaults) private var animationsEnabled = true
    var body: some View {
        MountainVines(progress: progress, curtain: curtain, cover: cover)
            .allowsHitTesting(false).accessibilityHidden(true)
            .onAppear { if curtain { run() } }
            .onChange(of: trigger) { run() }
    }
    private func run() {
        guard !systemReduceMotion, animationsEnabled, !MountainExperience.isQAActive else { progress = 1; onFinish(); return }
        progress = 0
        withAnimation(.easeInOut(duration: duration)) { progress = 1 } completion: { onFinish() }
    }
}

private struct MountainVines: View, Animatable {
    var progress: Double
    let curtain: Bool
    var cover = false
    var animatableData: Double { get { progress } set { progress = newValue } }
    static let stem = Color(red: 0.18, green: 0.48, blue: 0.27)
    static let leaf = Color(red: 0.42, green: 0.74, blue: 0.36)
    var body: some View {
        Canvas { context, size in
            guard progress < 1 else { return }
            if curtain {
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(MountainStyle.ink.opacity(min(1, 2 - progress * 2))))
            }
            let head = min(1, progress * 2), tail = max(0, progress * 2 - 1)
            if cover {
                // A leafy hedge thickens behind the vines until nothing shows through.
                let density = min(head, 1 - tail)
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 0.08, green: 0.30, blue: 0.22).opacity(density * density * (3 - 2 * density))))
            }
            let vines = cover ? 18 : 10, samples = 48
            for vine in 0..<vines {
                let across = vine % 2 == 0 // alternate rows and columns
                let lane = (Double(vine / 2) + 0.5) / Double(vines / 2)
                let phase = Double(vine) * 1.7
                func point(_ t: Double) -> CGPoint {
                    let wave = sin(t * 9 + phase) * 0.06 + sin(t * 23 + phase * 2) * 0.015
                    return across ? CGPoint(x: t * size.width, y: (lane + wave) * size.height)
                                  : CGPoint(x: (lane + wave) * size.width, y: t * size.height)
                }
                let from = Int(tail * Double(samples)), to = Int(head * Double(samples))
                guard to > from else { continue }
                var path = Path()
                path.move(to: point(Double(from) / Double(samples)))
                for i in (from + 1)...to { path.addLine(to: point(Double(i) / Double(samples))) }
                context.stroke(path, with: .color(Self.stem), style: StrokeStyle(lineWidth: cover ? 8 : 5, lineCap: .round, lineJoin: .round))
                for i in stride(from: from + 1, through: to, by: 1) where (i + vine) % 4 == 0 {
                    let p = point(Double(i) / Double(samples)), q = point(Double(i + 1) / Double(samples))
                    var leaf = context
                    leaf.translateBy(x: p.x, y: p.y)
                    leaf.rotate(by: .radians(atan2(q.y - p.y, q.x - p.x) + (i % 8 < 4 ? 0.9 : -0.9)))
                    leaf.fill(Path(ellipseIn: CGRect(x: 0, y: -4, width: 16, height: 8)), with: .color(Self.leaf))
                    if (i + vine) % 12 == 0 {
                        leaf.fill(Path(ellipseIn: CGRect(x: -4, y: -4, width: 8, height: 8)), with: .color(MountainStyle.gold))
                    }
                }
            }
        }
    }
}


/// "Tally Tangle" hand-lettered in vines. Separate vines grow in from the top and sides of
/// the screen; each reaches the top of one letter and writes it in script, with a slimmer vine
/// twisting around the stem, tendrils curling from the ends, and leaves, berries and blossoms.
/// `grow` runs the whole performance from 0 to 1; running it back unwinds every vine.
/// Draw it full screen; `frame` is where the lettering sits inside that space.
struct MountainVineTitle: View, Animatable {
    var grow: Double
    var frame: CGRect
    var active = true
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage("animationsEnabled", store: MountainExperience.defaults) private var animationsEnabled = true
    @Environment(\.scenePhase) private var scenePhase
    var animatableData: Double { get { grow } set { grow = newValue } }

    private enum Edge { case top, leading, trailing }
    private struct Stroke {
        var points: [CGPoint]
        var lengths: [CGFloat]
        var window: ClosedRange<Double> = 0...1
        var width: CGFloat = 6.4
        var feeder = false
        var curlStart = false
        var curlEnd = false
        var total: CGFloat { lengths.last ?? 0 }
        init(_ points: [CGPoint]) {
            self.points = points
            var lengths: [CGFloat] = [0]
            for i in points.indices.dropFirst() { lengths.append(lengths[i - 1] + hypot(points[i].x - points[i - 1].x, points[i].y - points[i - 1].y)) }
            self.lengths = lengths
        }
    }
    /// One letter (or crossbar) and the screen edge its vine grows in from.
    private struct Part { let stroke: Stroke; let from: Edge; let order: Int }

    /// Catmull-Rom through a skeleton, ten samples per span.
    private static func smooth(_ points: [CGPoint]) -> [CGPoint] {
        guard points.count > 1 else { return points }
        var out: [CGPoint] = []
        for i in 0..<(points.count - 1) {
            let p0 = points[max(0, i - 1)], p1 = points[i], p2 = points[i + 1], p3 = points[min(points.count - 1, i + 2)]
            for step in 0..<10 {
                let t = CGFloat(step) / 10, t2 = t * t, t3 = t2 * t
                func c(_ a: CGFloat, _ b: CGFloat, _ c: CGFloat, _ d: CGFloat) -> CGFloat {
                    0.5 * (2 * b + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t2 + (-a + 3 * b - 3 * c + d) * t3)
                }
                out.append(CGPoint(x: c(p0.x, p1.x, p2.x, p3.x), y: c(p0.y, p1.y, p2.y, p3.y)))
            }
        }
        out.append(points[points.count - 1])
        return out
    }

    /// Script skeletons on a 100-unit line: baseline 78, x-height 44.
    private static let letters: [Character: (points: [(CGFloat, CGFloat)], advance: CGFloat)] = [
        "a": ([(0, 78), (12, 56), (24, 44), (16, 40), (6, 46), (2, 62), (8, 78), (18, 74), (24, 56), (25, 44), (25, 66), (29, 80), (36, 78)], 36),
        "l": ([(0, 78), (10, 52), (15, 22), (12, 4), (6, 10), (5, 34), (8, 62), (13, 80), (20, 78)], 20),
        "y": ([(0, 78), (4, 58), (6, 44), (7, 64), (13, 76), (21, 68), (24, 44), (24, 82), (22, 100), (14, 108), (7, 101), (13, 92), (32, 84)], 30),
        "n": ([(0, 78), (4, 60), (5, 44), (5, 78), (7, 60), (14, 44), (21, 48), (23, 62), (24, 78), (30, 78)], 30),
        "g": ([(0, 78), (12, 56), (24, 44), (16, 40), (6, 46), (2, 62), (8, 78), (18, 74), (24, 56), (25, 44), (25, 82), (23, 100), (15, 108), (8, 101), (14, 92), (30, 84)], 30),
        "e": ([(0, 74), (12, 66), (20, 56), (18, 46), (10, 44), (4, 54), (4, 68), (10, 79), (20, 80), (30, 72)], 28)
    ]
    private static let size = CGSize(width: 186, height: 216)

    private static let parts: [Part] = {
        var parts: [Part] = []
        func word(_ rest: String, top: CGFloat, inset: CGFloat, line: Int) {
            func at(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x + inset, y: y + top) }
            // A vine capital T: a wavy crossbar, written from the side, then the stem.
            var bar = Stroke(smooth([(-4, 16), (6, 6), (20, 11), (34, 3), (50, 9), (56, 4)].map { at($0.0, $0.1) }))
            if line == 1 { bar = Stroke(bar.points.reversed()) }
            bar.width = 5.2; bar.curlStart = true; bar.curlEnd = true
            parts.append(Part(stroke: bar, from: line == 0 ? .leading : .trailing, order: 0))
            // The cursive body, split at the top of each letter so a vine can land there and write it.
            var skeleton = [(27, 8), (25, 36), (24, 64), (28, 80), (38, 78)].map { at($0.0, $0.1) }
            var anchors = [0]
            var x: CGFloat = 38
            for character in rest {
                guard let letter = letters[character] else { continue }
                let points = letter.points.dropFirst().map { at($0.0 + x, $0.1) }
                let top = points.indices.min { points[$0].y < points[$1].y } ?? 0
                anchors.append(skeleton.count + top)
                skeleton += points
                x += letter.advance
            }
            let dense = smooth(skeleton)
            let cuts = anchors.map { $0 * 10 } + [dense.count - 1]
            for k in 0..<(cuts.count - 1) {
                var stroke = Stroke(Array(dense[cuts[k]...cuts[k + 1]]))
                stroke.curlEnd = k == cuts.count - 2
                let middle = stroke.points[0].x
                let from: Edge = line == 0 ? .top : middle < 60 ? .leading : .trailing
                parts.append(Part(stroke: stroke, from: from, order: k + 1 + line))
            }
        }
        word("ally", top: 0, inset: 18, line: 0)
        word("angle", top: 104, inset: 0, line: 1)
        return parts
    }()
    static var aspect: CGFloat { size.height / size.width }

    /// Each feeder vine grows first, then its letter; letters start a beat apart.
    private static func windows(order: Int) -> (feeder: ClosedRange<Double>, letter: ClosedRange<Double>) {
        let start = Double(order) * 0.035
        return (start...(start + 0.3), (start + 0.28)...min(1, start + 0.62))
    }

    /// A gently swaying vine from the screen edge to the letter's starting point.
    private func feeder(to target: CGPoint, from edge: Edge, edges: (left: CGFloat, right: CGFloat, top: CGFloat), seed: Int, time: Double) -> Stroke {
        let wobble = { (k: Double) in CGFloat(sin(time * 0.5 + Double(seed) * 1.9 + k) * 3) }
        let j = CGFloat((seed * 37) % 17) - 8
        var skeleton: [CGPoint]
        switch edge {
        case .top:
            skeleton = [CGPoint(x: target.x + j, y: edges.top),
                        CGPoint(x: target.x + j * 0.6 + 10 + wobble(0), y: edges.top + (target.y - edges.top) * 0.4),
                        CGPoint(x: target.x - 8 + wobble(1), y: edges.top + (target.y - edges.top) * 0.75),
                        CGPoint(x: target.x, y: target.y - 9), target]
        case .leading, .trailing:
            let x = edge == .leading ? edges.left : edges.right
            let lift = target.y - 34 - CGFloat(seed % 3) * 6
            skeleton = [CGPoint(x: x, y: lift - 10 + j),
                        CGPoint(x: x + (target.x - x) * 0.35, y: lift - 6 + wobble(0)),
                        CGPoint(x: x + (target.x - x) * 0.72, y: lift + 8 + wobble(1)),
                        CGPoint(x: target.x, y: target.y - 9), target]
        }
        var stroke = Stroke(Self.smooth(skeleton))
        stroke.width = 3.4; stroke.feeder = true
        return stroke
    }

    var body: some View {
        let still = systemReduceMotion || !animationsEnabled
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: still || !active || scenePhase != .active)) { timeline in
            Canvas { context, size in
                let time = still ? 0 : timeline.date.timeIntervalSinceReferenceDate
                let scale = frame.width / Self.size.width
                guard scale > 0 else { return }
                context.translateBy(x: frame.minX, y: frame.minY)
                context.scaleBy(x: scale, y: scale)
                let edges = (left: -frame.minX / scale - 6, right: (size.width - frame.minX) / scale + 6, top: -frame.minY / scale - 6)
                for part in Self.parts {
                    let window = Self.windows(order: part.order)
                    var vine = feeder(to: part.stroke.points[0], from: part.from, edges: edges, seed: part.order * 7 + (part.from == .top ? 1 : 3), time: time)
                    vine.window = window.feeder
                    var letter = part.stroke
                    letter.window = window.letter
                    // Side vines draw themselves into their letter once it's written, leaving the title clear;
                    // vines from the top stay, hanging from the canopy.
                    let absorbed = part.from == .top ? 0 : min(1, max(0, (grow - window.letter.upperBound) / 0.12))
                    for (index, stroke) in [vine, letter].enumerated() {
                        let local = (grow - stroke.window.lowerBound) / (stroke.window.upperBound - stroke.window.lowerBound)
                        guard local > 0, index == 1 || absorbed < 1 else { continue }
                        draw(stroke, index: part.order * 2 + index, reach: min(1, local), tail: index == 0 ? absorbed : 0, in: &context, time: time)
                    }
                }
            }
        }
        .allowsHitTesting(false).accessibilityHidden(true)
    }

    private static let stemDark = Color(red: 0.13, green: 0.38, blue: 0.22)
    private static let stem = Color(red: 0.24, green: 0.56, blue: 0.30)
    private static let highlight = Color(red: 0.62, green: 0.86, blue: 0.48)
    private static let leafColors = [Color(red: 0.42, green: 0.74, blue: 0.36), Color(red: 0.31, green: 0.62, blue: 0.29), Color(red: 0.55, green: 0.80, blue: 0.40)]
    private static let petals = [Color(red: 1, green: 0.58, blue: 0.72), MountainStyle.gold, Color(red: 0.74, green: 0.62, blue: 1)]

    private func draw(_ stroke: Stroke, index: Int, reach: Double, tail: Double = 0, in context: inout GraphicsContext, time: Double) {
        let head = stroke.total * reach
        let count = stroke.lengths.firstIndex { $0 > head } ?? stroke.points.count
        let first = stroke.lengths.firstIndex { $0 >= stroke.total * tail } ?? 0
        guard count - first > 1 else { return }
        let points = Array(stroke.points[first..<count])
        let lengths = Array(stroke.lengths[first..<count])
        func normal(_ i: Int) -> CGVector {
            let a = points[max(0, i - 1)], b = points[min(points.count - 1, i + 1)]
            let length = max(0.001, hypot(b.x - a.x, b.y - a.y))
            return CGVector(dx: -(b.y - a.y) / length, dy: (b.x - a.x) / length)
        }
        // Letters swell through the middle; feeders thin slightly toward the letter. Both taper at the growing tip.
        func width(_ i: Int) -> CGFloat {
            let s = lengths[i], u = s / max(1, stroke.total)
            let profile = stroke.feeder ? 1 - 0.25 * u : 0.55 + 0.45 * sin(.pi * min(1, u * 1.05 + 0.08))
            let trailing = tail > 0 ? min(1, (s - (lengths.first ?? 0)) / 10 + 0.15) : 1
            return stroke.width * profile * min(1, (head - s) / 10 + 0.15) * trailing
        }
        var left: [CGPoint] = [], right: [CGPoint] = []
        for i in points.indices {
            let n = normal(i), w = width(i) / 2
            left.append(CGPoint(x: points[i].x + n.dx * w, y: points[i].y + n.dy * w))
            right.append(CGPoint(x: points[i].x - n.dx * w, y: points[i].y - n.dy * w))
        }
        var body = Path(); body.addLines(left + right.reversed()); body.closeSubpath()
        var shadow = context; shadow.translateBy(x: 0.8, y: 1.6)
        shadow.fill(body, with: .color(MountainStyle.ink.opacity(0.5)))
        context.fill(body, with: .color(Self.stemDark))
        var core = Path(); core.addLines(points)
        context.stroke(core, with: .color(Self.stem), style: StrokeStyle(lineWidth: stroke.width * 0.42, lineCap: .round, lineJoin: .round))
        var shine = Path()
        shine.addLines(points.indices.map { i in let n = normal(i); return CGPoint(x: points[i].x - n.dx * width(i) * 0.22, y: points[i].y - n.dy * width(i) * 0.22) })
        context.stroke(shine, with: .color(Self.highlight.opacity(0.5)), style: StrokeStyle(lineWidth: 0.7, lineCap: .round))

        // A slender vine twists smoothly around each letter, a little behind its stem.
        if !stroke.feeder {
            var twine = Path()
            for i in points.indices where lengths[i] <= head - 12 {
                let n = normal(i), offset = sin(lengths[i] * 0.22 + Double(index)) * (width(i) * 0.5 + 1.2)
                let q = CGPoint(x: points[i].x + n.dx * offset, y: points[i].y + n.dy * offset)
                if twine.isEmpty { twine.move(to: q) } else { twine.addLine(to: q) }
            }
            context.stroke(twine, with: .color(Self.highlight.opacity(0.85)), style: StrokeStyle(lineWidth: 0.9, lineCap: .round, lineJoin: .round))
        }

        // Leaves alternate sides and unfurl once the stem has passed; feeders are sparser.
        var s: CGFloat = (lengths.first ?? 0) + 6, side: CGFloat = index % 2 == 0 ? 1 : -1, leafIndex = 0
        while s < head - 3 {
            guard let i = lengths.firstIndex(where: { $0 >= s }), i < points.count else { break }
            let n = normal(i), unfurl = min(1, (head - s) / 12)
            let size = (leafIndex % 4 == 0 ? 7.5 : 5.5) * unfurl
            let base = CGPoint(x: points[i].x + n.dx * width(i) * 0.4 * side, y: points[i].y + n.dy * width(i) * 0.4 * side)
            let angle = atan2(n.dy * side, n.dx * side) - 0.5 * side + sin(time * 0.9 + Double(leafIndex + index) * 1.7) * 0.14
            var leaf = context
            leaf.translateBy(x: base.x, y: base.y); leaf.rotate(by: .radians(angle))
            var blade = Path()
            blade.move(to: .zero)
            blade.addQuadCurve(to: CGPoint(x: size, y: 0), control: CGPoint(x: size * 0.45, y: -size * 0.42))
            blade.addQuadCurve(to: .zero, control: CGPoint(x: size * 0.45, y: size * 0.42))
            leaf.fill(blade, with: .color(Self.leafColors[(leafIndex + index) % 3]))
            var rib = Path(); rib.move(to: .zero); rib.addLine(to: CGPoint(x: size * 0.8, y: 0))
            leaf.stroke(rib, with: .color(Self.stemDark.opacity(0.6)), lineWidth: 0.4)
            if !stroke.feeder && leafIndex % 6 == 3 {
                for k in 0..<3 {
                    let b = CGPoint(x: points[i].x - n.dx * side * (3 + CGFloat(k % 2) * 1.6), y: points[i].y - n.dy * side * (3 + CGFloat(k) * 1.4))
                    context.fill(Path(ellipseIn: CGRect(x: b.x - 1.1 * unfurl, y: b.y - 1.1 * unfurl, width: 2.2 * unfurl, height: 2.2 * unfurl)), with: .color(MountainStyle.gold))
                }
            }
            s += stroke.feeder ? 14 : leafIndex % 3 == 0 ? 11 : 8
            side = -side; leafIndex += 1
        }

        // Tendrils curl from crossbar ends and the last letter of each word once written.
        if reach >= 1 {
            for end in [stroke.curlStart ? 0 : nil, stroke.curlEnd ? points.count - 1 : nil].compactMap({ $0 }) {
                let a = points[end], b = points[end == 0 ? 1 : end - 1]
                var heading = atan2(a.y - b.y, a.x - b.x)
                var q = a, turn = (end == 0 ? -1.0 : 1.0) * (0.34 + sin(time * 0.7 + Double(index)) * 0.03)
                var tendril = Path(); tendril.move(to: q)
                for step in 0..<22 {
                    let length = 1.6 * (1 - Double(step) / 26)
                    heading += turn; turn *= 1.06
                    q = CGPoint(x: q.x + cos(heading) * length, y: q.y + sin(heading) * length)
                    tendril.addLine(to: q)
                }
                context.stroke(tendril, with: .color(Self.highlight), style: StrokeStyle(lineWidth: 0.9, lineCap: .round, lineJoin: .round))
            }
        }

        // One blossom opens where each feeder meets its letter, and at the end of every crossbar.
        let bloom = min(1, max(0, (grow - 0.8) / 0.2))
        guard bloom > 0, stroke.feeder || stroke.curlStart else { return }
        let c = stroke.feeder ? points[points.count - 1] : points[points.count - 1]
        let r = 2.8 * bloom + sin(time * 1.2 + Double(index)) * 0.15
        for petal in 0..<5 {
            let a = Double(petal) * 2 * .pi / 5 + Double(index)
            context.fill(Path(ellipseIn: CGRect(x: c.x + cos(a) * r - r * 0.62, y: c.y + sin(a) * r - r * 0.62, width: r * 1.24, height: r * 1.24)),
                         with: .color(Self.petals[index % 3]))
        }
        context.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.42, y: c.y - r * 0.42, width: r * 0.84, height: r * 0.84)), with: .color(MountainStyle.cream))
    }
}
