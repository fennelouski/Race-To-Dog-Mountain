// Authored geometric layers for Vision Pro. Run from the repository root.
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let directory = URL(fileURLWithPath: "Vision/VisionAssets.xcassets/VisionIcon.solidimagestack")
let pine = CGColor(red: 0.025, green: 0.12, blue: 0.17, alpha: 1)
let gold = CGColor(red: 1, green: 0.73, blue: 0.28, alpha: 1)
let cream = CGColor(red: 1, green: 0.95, blue: 0.82, alpha: 1)
let teal = CGColor(red: 0.22, green: 0.49, blue: 0.48, alpha: 1)
let mint = CGColor(red: 0.42, green: 0.88, blue: 0.81, alpha: 1)
let info: [String: Any] = ["author": "xcode", "version": 1]
func json(_ object: [String: Any], at url: URL) throws {
    try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]).write(to: url)
}
func polygon(_ points: [CGPoint], color: CGColor, in context: CGContext) {
    context.beginPath(); context.addLines(between: points); context.closePath()
    context.setFillColor(color); context.fillPath()
}
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
try json(["info": info, "layers": ["Front", "Middle", "Back"].map { ["filename": "\($0).solidimagestacklayer"] }], at: directory.appendingPathComponent("Contents.json"))
try json(["info": info], at: directory.deletingLastPathComponent().appendingPathComponent("Contents.json"))
for layer in ["Back", "Middle", "Front"] {
    let folder = directory.appendingPathComponent("\(layer).solidimagestacklayer")
    let content = folder.appendingPathComponent("Content.imageset")
    try FileManager.default.createDirectory(at: content, withIntermediateDirectories: true)
    try json(["info": info], at: folder.appendingPathComponent("Contents.json"))
    try json(["info": info, "images": [["idiom": "vision", "scale": "2x", "filename": "\(layer).png"]]], at: content.appendingPathComponent("Contents.json"))
    let context = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 4096, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    if layer == "Back" {
        context.setFillColor(pine); context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
        context.setFillColor(gold); context.fillEllipse(in: CGRect(x: 470, y: 480, width: 360, height: 360))
    } else if layer == "Middle" {
        polygon([CGPoint(x: 70,y: 190),CGPoint(x: 490,y: 800),CGPoint(x: 970,y: 190)], color: teal, in: context)
        polygon([CGPoint(x: 490,y: 800),CGPoint(x: 610,y: 620),CGPoint(x: 480,y: 670),CGPoint(x: 360,y: 610)], color: cream, in: context)
        polygon([CGPoint(x: 490,y: 800),CGPoint(x: 970,y: 190),CGPoint(x: 550,y: 280),CGPoint(x: 440,y: 570)], color: mint, in: context)
    } else {
        polygon([CGPoint(x: 40,y: 70),CGPoint(x: 310,y: 400),CGPoint(x: 540,y: 170),CGPoint(x: 750,y: 410),CGPoint(x: 984,y: 90)], color: pine, in: context)
        context.setFillColor(gold)
        for (x,y,w) in [(480,110,72),(420,220,58),(500,305,44),(548,380,32)] {
            context.fill(CGRect(x: x,y: y,width: w,height: w))
        }
    }
    let image = context.makeImage()!
    let destination = CGImageDestinationCreateWithURL(content.appendingPathComponent("\(layer).png") as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, [kCGImagePropertyPNGDictionary: [kCGImagePropertyPNGDescription: "Original geometric artwork rendered by Tools/generate-vision-icon.swift. Pine/teal/cream mountain, amber sun and square climbing trail; separate Vision Pro depth layers."]] as CFDictionary)
    precondition(CGImageDestinationFinalize(destination), "Could not write \(layer)")
}
