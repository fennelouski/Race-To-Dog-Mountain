import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@main struct AvatarChecks {
    @MainActor static func main() throws {
        let names = ["Nathan", "Player 1", "Player 2"] + ComputerDifficulty.allCases.map(\.name)
        let ctx = CGContext(data:nil,width:800,height:600,bitsPerComponent:8,bytesPerRow:3200,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(red:0.025,green:0.12,blue:0.17,alpha:1));ctx.fill(CGRect(x:0,y:0,width:800,height:600))
        for (i,name) in names.enumerated() {
            let image = MountainFonster.image(seed:name)!
            precondition(image.width == 128 && image.height == 128)
            ctx.draw(image,in:CGRect(x:(i%5)*160+16,y:600-(i/5+1)*150+10,width:128,height:128))
        }
        let output = URL(fileURLWithPath:CommandLine.arguments[1]);let image=ctx.makeImage()!
        let dest=CGImageDestinationCreateWithURL(output as CFURL,UTType.png.identifier as CFString,1,nil)!
        CGImageDestinationAddImage(dest,image,nil);precondition(CGImageDestinationFinalize(dest))
        let data=try Data(contentsOf:output)
        let photo=MountainAvatarPhotos.prepare(data)!
        let src=CGImageSourceCreateWithData(photo as CFData,nil)!
        let small=CGImageSourceCreateImageAtIndex(src,0,nil)!
        precondition(max(small.width,small.height)<=256)
        precondition(MountainAvatarPhotos.prepare(Data(repeating:0,count:25_000_001))==nil)
        print("PASS: 19 name-based avatar renders; picker photo downsampling to 256px and oversized/corrupt input guard.")
    }
}
