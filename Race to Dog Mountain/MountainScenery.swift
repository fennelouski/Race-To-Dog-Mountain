import SwiftUI

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
                for vine in 0..<7 {
                    let anchor = (Double(vine) + 0.5) / 7
                    let length = h * (0.09 + Double((vine * 37) % 5) * 0.035)
                    let sway = sin(time * 0.5 + Double(vine) * 1.3) * w * 0.02
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
    var duration = 1.4
    var onFinish: () -> Void = {}
    @State private var progress = 1.0
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage("animationsEnabled", store: MountainExperience.defaults) private var animationsEnabled = true
    var body: some View {
        MountainVines(progress: progress, curtain: curtain)
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
            let vines = 10, samples = 48
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
                context.stroke(path, with: .color(Self.stem), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
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
