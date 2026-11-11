// Static vector exports of existing MountainScenery geometry. Run from repository root.
import Foundation
import CoreGraphics
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Race to Dog Mountain/Images.xcassets")
let w = 375.0, h = 812.0
func color(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor { CGColor(red: r, green: g, blue: b, alpha: a) }
let ink = color(0.025, 0.12, 0.17), gold = color(1, 0.73, 0.28)
func pdf(_ name: String, width: Double = w, height: Double = h, draw: (CGContext) -> Void) throws {
    let folder = root.appendingPathComponent(name + ".imageset")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    var bounds = CGRect(x: 0, y: 0, width: width, height: height)
    guard let context = CGContext(folder.appendingPathComponent(name + ".pdf") as CFURL, mediaBox: &bounds, nil) else { fatalError("PDF context") }
    context.beginPDFPage(nil); context.translateBy(x: 0, y: height); context.scaleBy(x: 1, y: -1)
    draw(context); context.endPDFPage(); context.closePDF()
    let info: [String: Any] = ["images": [["filename": name + ".pdf", "idiom": "universal"]], "info": ["author": "xcode", "version": 1], "properties": ["preserves-vector-representation": true]]
    try JSONSerialization.data(withJSONObject: info, options: [.prettyPrinted, .sortedKeys]).write(to: folder.appendingPathComponent("Contents.json"))
}
try pdf("LaunchSky") { context in
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [ink, color(0.08, 0.32, 0.36), color(0.32, 0.57, 0.53)] as CFArray, locations: [0, 0.5, 1])!
    context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: w * 0.8, y: h), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    for i in 0..<30 {
        let x = Double((i * 73 + 17) % 307) / 307 * w, y = Double((i * 47 + 11) % 271) / 271 * h * 0.65, side = i % 4 == 0 ? 3.0 : 1.5
        context.setFillColor(color(1, 0.95, 0.82, 0.18 + (sin(Double(i)) + 1) * 0.18)); context.fillEllipse(in: CGRect(x: x, y: y, width: side, height: side))
    }
    for i in 0..<5 {
        let x = Double(i) * w * 0.3 - w * 0.2 + sin(Double(i)) * w * 0.08, y = h * (0.40 + Double(i % 3) * 0.08)
        context.setFillColor(color(1, 0.95, 0.82, 0.15)); context.addPath(CGPath(roundedRect: CGRect(x: x, y: y, width: w * 0.38, height: 2 + Double(i % 2) * 3), cornerWidth: 3, cornerHeight: 3, transform: nil)); context.fillPath()
    }
}
try pdf("LaunchSun", width: 128, height: 128) { context in context.setFillColor(gold); context.fillEllipse(in: CGRect(x: 0, y: 0, width: 128, height: 128)) }
// Asset keeps its historical name; it now holds the hedges and hanging vines.
try pdf("LaunchRidges") { context in
    let hedges: [(Double, Double, Double, CGColor)] = [(0.62, 0.05, 0.075, color(0.22,0.49,0.40)), (0.72, 0.04, 0.065, color(0.10,0.34,0.27)), (0.82, 0.03, 0.055, ink)]
    for (layer, hedge) in hedges.enumerated() {
        context.setFillColor(hedge.3)
        let r = hedge.2 * w
        var x = -r
        while x < w + r {
            let u = x / w, y = h * (hedge.0 + sin(u * 5 + Double(layer) * 2) * hedge.1)
            let size = r * (0.8 + 0.4 * (sin(u * 31 + Double(layer)) + 1) / 2)
            context.fillEllipse(in: CGRect(x: x - size, y: y - size, width: size * 2, height: size * 2)); x += r * 1.3
        }
        context.fill(CGRect(x: 0, y: h * hedge.0, width: w, height: h * (1 - hedge.0)))
    }
    for vine in 0..<7 {
        let anchor = (Double(vine) + 0.5) / 7, length = h * (0.09 + Double((vine * 37) % 5) * 0.035)
        func point(_ t: Double) -> CGPoint { CGPoint(x: anchor * w + sin(t * 7 + Double(vine) * 2.1) * w * 0.035 * t, y: -4 + t * length) }
        context.beginPath(); context.move(to: point(0))
        for i in 1...28 { context.addLine(to: point(Double(i) / 28)) }
        context.setStrokeColor(color(0.18,0.48,0.27,0.9)); context.setLineWidth(3); context.setLineCap(.round); context.strokePath()
        for i in stride(from: 3, through: 28, by: 3) {
            let p = point(Double(i) / 28), q = point(Double(i + 1) / 28)
            context.saveGState(); context.translateBy(x: p.x, y: p.y)
            context.rotate(by: atan2(q.y - p.y, q.x - p.x) + (i % 6 == 0 ? 0.9 : -0.9))
            context.setFillColor(color(0.42,0.74,0.36,0.9)); context.fillEllipse(in: CGRect(x: 0, y: -3.5, width: 14, height: 7)); context.restoreGState()
        }
    }
    context.beginPath()
    context.addArc(center: CGPoint(x: w * 0.66, y: h * 0.70), radius: w * 0.04, startAngle: -.pi / 2, endAngle: .pi, clockwise: false)
    context.addCurve(to: CGPoint(x: w * 0.43, y: h), control1: CGPoint(x: w * 0.2, y: h * 0.82), control2: CGPoint(x: w * 0.95, y: h * 0.90))
    context.setStrokeColor(color(1,0.73,0.28,0.18)); context.setLineWidth(2); context.setLineDash(phase: 0, lengths: [4,9]); context.strokePath()
}
print("Generated three static vector layers from the Tally Tangle scenery geometry.")
