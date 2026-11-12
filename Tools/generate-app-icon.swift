// Tally Tangle icon: two braided vines (gold row player, mint column player) over a leafy canopy disc.
// Run from the repository root. Writes the 1024 master, Vision depth layers, then resizes every
// existing PNG icon in place with sips so each keeps its current pixel size.
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let size = 1024.0
func color(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor { CGColor(red: r, green: g, blue: b, alpha: a) }
let ink = color(0.025, 0.12, 0.17), gold = color(1, 0.73, 0.28), mint = color(0.42, 0.88, 0.81)
let stem = color(0.18, 0.48, 0.27), leaf = color(0.42, 0.74, 0.36), cream = color(1, 0.95, 0.82)

func canvas() -> CGContext {
    let c = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 4096,
                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    c.translateBy(x: 0, y: size); c.scaleBy(x: 1, y: -1) // top-left origin
    c.setLineCap(.round); c.setLineJoin(.round)
    return c
}
/// A vine climbing from the bottom; `phase` offsets the two strands so they braid.
func strand(_ phase: Double) -> (Double) -> CGPoint {
    { t in CGPoint(x: size / 2 + sin(t * .pi * 2.6 + phase) * 210 * (0.35 + t * 0.65), y: size * (0.94 - t * 0.78)) }
}
func drawLeaf(_ c: CGContext, at p: CGPoint, angle: Double, length: Double, fill: CGColor) {
    c.saveGState(); c.translateBy(x: p.x, y: p.y); c.rotate(by: angle)
    let path = CGMutablePath()
    path.move(to: .zero)
    path.addQuadCurve(to: CGPoint(x: length, y: 0), control: CGPoint(x: length * 0.5, y: -length * 0.42))
    path.addQuadCurve(to: .zero, control: CGPoint(x: length * 0.5, y: length * 0.42))
    c.addPath(path); c.setFillColor(fill); c.fillPath(); c.restoreGState()
}
/// Strokes a strand (all of it, or only the runs where it crosses in front) as an ink outline, then its colour.
func drawVine(_ c: CGContext, phase: Double, tint: CGColor, frontOnly: Bool) {
    let f = strand(phase), steps = 240
    var runs: [CGMutablePath] = [], current: CGMutablePath?
    for i in 0...steps {
        let t = Double(i) / Double(steps)
        if frontOnly && cos(t * Double.pi * 2.6 + phase) < 0 { current = nil; continue }
        if let path = current { path.addLine(to: f(t)) } else { let path = CGMutablePath(); path.move(to: f(t)); runs.append(path); current = path }
    }
    c.setLineCap(frontOnly ? .butt : .round)
    for (stroke, width) in [(ink, 66.0), (tint, 48.0)] {
        for run in runs { c.addPath(run); c.setStrokeColor(stroke); c.setLineWidth(width); c.strokePath() }
    }
}
func drawLeaves(_ c: CGContext, phase: Double) {
    let f = strand(phase)
    for (n, t) in stride(from: 0.12, through: 0.92, by: 0.16).enumerated() {
        let p = f(t), q = f(t + 0.01)
        drawLeaf(c, at: p, angle: atan2(q.y - p.y, q.x - p.x) + (n % 2 == 0 ? 1.1 : -1.1), length: 120 - t * 40, fill: leaf)
    }
    drawLeaf(c, at: f(1), angle: -.pi / 2 + phase * 0.2, length: 90, fill: leaf)
}

func back(_ c: CGContext) {
    c.setFillColor(ink); c.fill(CGRect(x: 0, y: 0, width: size, height: size))
    c.setFillColor(color(0.16, 0.36, 0.30)); c.fillEllipse(in: CGRect(x: 212, y: 132, width: 600, height: 600))
}
func middle(_ c: CGContext) {
    drawVine(c, phase: 0, tint: gold, frontOnly: false)
    drawVine(c, phase: .pi, tint: mint, frontOnly: false)
}
func front(_ c: CGContext) {
    drawVine(c, phase: 0, tint: gold, frontOnly: true) // gold passes over mint at alternate crossings
    drawLeaves(c, phase: 0); drawLeaves(c, phase: .pi)
    // Number tiles caught in the tangle.
    for (x, y, s) in [(300.0, 610.0, 74.0), (650, 470, 62), (420, 300, 50)] {
        c.saveGState(); c.translateBy(x: x, y: y); c.rotate(by: 0.18)
        let r = CGRect(x: -s / 2, y: -s / 2, width: s, height: s)
        c.addPath(CGPath(roundedRect: r.insetBy(dx: -6, dy: -6), cornerWidth: 16, cornerHeight: 16, transform: nil)); c.setFillColor(ink); c.fillPath()
        c.addPath(CGPath(roundedRect: r, cornerWidth: 12, cornerHeight: 12, transform: nil)); c.setFillColor(cream); c.fillPath()
        c.restoreGState()
    }
}

func write(_ image: CGImage, to path: String) {
    let d = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(d, image, [kCGImagePropertyPNGDictionary: [kCGImagePropertyPNGDescription: "Tally Tangle icon rendered by Tools/generate-app-icon.swift"]] as CFDictionary)
    precondition(CGImageDestinationFinalize(d), "Could not write \(path)")
}

// Vision Pro depth layers.
let vision = "Vision/VisionAssets.xcassets/VisionIcon.solidimagestack"
for (name, draw) in [("Back", back), ("Middle", middle), ("Front", front)] as [(String, (CGContext) -> Void)] {
    let c = canvas(); draw(c)
    write(c.makeImage()!, to: "\(vision)/\(name).solidimagestacklayer/Content.imageset/\(name).png")
}
// Flattened opaque master.
let master = canvas(); back(master); middle(master); front(master)
let flat = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 4096,
                     space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
flat.draw(master.makeImage()!, in: CGRect(x: 0, y: 0, width: size, height: size))
let masterPath = "Tally Tangle/Images.xcassets/AppIcon.appiconset/AppIcon-1024.png"
write(flat.makeImage()!, to: masterPath)

// Every other square icon keeps its pixel size.
let roots = ["Tally Tangle/Images.xcassets/AppIcon.appiconset", "Tally Tangle/Icons/iphone",
             "Watch/WatchAssets.xcassets/WatchIcon.appiconset", "Messages/Assets.xcassets/AppIcon.appiconset"]
for root in roots {
    for file in (try? FileManager.default.contentsOfDirectory(atPath: root)) ?? [] {
        let path = "\(root)/\(file)"
        guard path != masterPath, file.hasSuffix(".png") || file.hasPrefix("iTunesArtwork"),
              let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int, let h = props[kCGImagePropertyPixelHeight] as? Int, w == h else { continue }
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
        p.arguments = ["-s", "format", "png", "-z", "\(h)", "\(w)", masterPath, "--out", path]
        p.standardOutput = FileHandle.nullDevice
        try p.run(); p.waitUntilExit()
    }
}
print("Generated Tally Tangle icons.")
