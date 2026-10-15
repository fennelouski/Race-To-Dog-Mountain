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
    static func player(_ index: Int) -> Color { index == 0 ? gold : mint }
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
        return player == 0 ? Color(red: 0.82, green: 0.34, blue: 0.04)
                           : Color(red: 0.04, green: 0.44, blue: 0.40)
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
                let ridges: [[CGPoint]] = [
                    [CGPoint(x: 0, y: 0.69), CGPoint(x: 0.18, y: 0.51), CGPoint(x: 0.32, y: 0.64), CGPoint(x: 0.62, y: 0.47), CGPoint(x: 0.86, y: 0.66), CGPoint(x: 1, y: 0.59)],
                    [CGPoint(x: 0, y: 0.78), CGPoint(x: 0.24, y: 0.59), CGPoint(x: 0.39, y: 0.72), CGPoint(x: 0.70, y: 0.58), CGPoint(x: 1, y: 0.78)],
                    [CGPoint(x: 0, y: 0.81), CGPoint(x: 0.15, y: 0.76), CGPoint(x: 0.38, y: 0.83), CGPoint(x: 0.62, y: 0.72), CGPoint(x: 0.83, y: 0.82), CGPoint(x: 1, y: 0.75)]
                ]
                let colors = [Color(red: 0.22, green: 0.49, blue: 0.48), Color(red: 0.10, green: 0.32, blue: 0.36), MountainStyle.ink]
                for layer in ridges.indices {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: h))
                    for point in ridges[layer] { path.addLine(to: CGPoint(x: point.x * w, y: point.y * h)) }
                    path.addLine(to: CGPoint(x: w, y: h)); path.closeSubpath()
                    context.fill(path, with: .color(colors[layer]))
                }
                // An exact geometric trail, echoed by the game's row/column path.
                var trail = Path()
                trail.move(to: CGPoint(x: w * 0.62, y: h * 0.73))
                trail.addCurve(to: CGPoint(x: w * 0.43, y: h), control1: CGPoint(x: w * 0.2, y: h * 0.82), control2: CGPoint(x: w * 0.95, y: h * 0.90))
                context.stroke(trail, with: .color(MountainStyle.gold.opacity(0.14)), style: StrokeStyle(lineWidth: 2, dash: [4, 9], dashPhase: reduceMotion ? 0 : -time * 3))
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
                        context.fill(Path(roundedRect: CGRect(x: x, y: y, width: 4, height: 8), cornerRadius: 1), with: .color(MountainStyle.player(i % 2).opacity(0.7)))
                    }
                }
            }
        }
        .ignoresSafeArea().allowsHitTesting(false).accessibilityHidden(true)
    }
}
