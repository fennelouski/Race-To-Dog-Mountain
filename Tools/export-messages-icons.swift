// Export the approved mountain artwork to Apple's Messages icon dimensions.
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let source = URL(fileURLWithPath: "Messages/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png")
let artwork = CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithURL(source as CFURL, nil)!, 0, nil)!
let directory = URL(fileURLWithPath: "Messages/Assets.xcassets/MessagesIcon.stickersiconset")
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
var images: [[String: String]] = []
for (idiom, width, height, scales) in [
    ("iphone", 60, 45, [2, 3]), ("ipad", 67, 50, [2]), ("ipad", 74, 55, [2]),
    ("universal", 27, 20, [2, 3]), ("universal", 32, 24, [2, 3]),
    ("ios-marketing", 1024, 768, [1])
] {
    for scale in scales {
        let w = width * scale, h = height * scale
        let context = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        context.setFillColor(CGColor(red: 0, green: 0.12, blue: 0.16, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: w, height: h))
        context.interpolationQuality = .high
        // Preserve the complete square artwork and its proportions in the wider Messages well.
        context.draw(artwork, in: CGRect(x: (w - h) / 2, y: 0, width: h, height: h))
        let name = "Messages-\(width)x\(height)-\(scale)x.png"
        let destination = CGImageDestinationCreateWithURL(directory.appendingPathComponent(name) as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, nil)
        precondition(CGImageDestinationFinalize(destination))
        var item = ["idiom": idiom, "size": "\(width)x\(height)", "scale": "\(scale)x", "filename": name]
        if idiom == "universal" || idiom == "ios-marketing" { item["platform"] = "ios" }
        images.append(item)
    }
}
let data = try JSONSerialization.data(withJSONObject: ["info": ["author": "xcode", "version": 1], "images": images], options: [.prettyPrinted, .sortedKeys])
try data.write(to: directory.appendingPathComponent("Contents.json"))
print("Exported \(images.count) opaque Messages icons from the approved artwork.")
