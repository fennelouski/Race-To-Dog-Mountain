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
try pdf("LaunchRidges") { context in
    let ridges: [[(Double, Double)]] = [[(0,0.69),(0.18,0.51),(0.32,0.64),(0.62,0.47),(0.86,0.66),(1,0.59)], [(0,0.78),(0.24,0.59),(0.39,0.72),(0.70,0.58),(1,0.78)], [(0,0.81),(0.15,0.76),(0.38,0.83),(0.62,0.72),(0.83,0.82),(1,0.75)]]
    for (layer, points) in ridges.enumerated() {
        context.beginPath(); context.move(to: CGPoint(x: 0, y: h))
        for point in points { context.addLine(to: CGPoint(x: point.0 * w, y: point.1 * h)) }
        context.addLine(to: CGPoint(x: w, y: h)); context.closePath(); context.setFillColor([color(0.22,0.49,0.48),color(0.10,0.32,0.36),ink][layer]); context.fillPath()
    }
    context.move(to: CGPoint(x: w * 0.62, y: h * 0.73)); context.addCurve(to: CGPoint(x: w * 0.43, y: h), control1: CGPoint(x: w * 0.2, y: h * 0.82), control2: CGPoint(x: w * 0.95, y: h * 0.90))
    context.setStrokeColor(color(1,0.73,0.28,0.14)); context.setLineWidth(2); context.setLineDash(phase: 0, lengths: [4,9]); context.strokePath()
}
print("Generated three static vector layers from MountainScenery geometry.")
