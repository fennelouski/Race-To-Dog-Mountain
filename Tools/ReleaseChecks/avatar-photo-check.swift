import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import CoreText
@main struct AvatarChecks {
    @MainActor static func main() async throws {
        let names = ["Nathan", "Player 1", "Player 2"] + ComputerDifficulty.allCases.map(\.name)
        let ctx = CGContext(data:nil,width:960,height:840,bitsPerComponent:8,bytesPerRow:3840,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(red:0.025,green:0.12,blue:0.17,alpha:1));ctx.fill(CGRect(x:0,y:0,width:960,height:840))
        let started = Date()
        var unique: Set<Data> = []
        for (i,name) in names.enumerated() {
            let image = await MountainFonster.portrait(seed:name)!
            precondition(image.width == 256 && image.height == 256, "Fuzzy renderer must succeed on this test host")
            let bytes = image.dataProvider!.data! as Data
            precondition(bytes.contains(where: { $0 != 0 }), "A rendered portrait cannot be blank")
            unique.insert(bytes)
            let again = await MountainFonster.portrait(seed:name)!
            precondition(image === again, "Repeated requests reuse the cached still")
            ctx.draw(image,in:CGRect(x:(i%5)*192+16,y:840-(i/5+1)*210+36,width:160,height:160))
            let label = NSAttributedString(string:name, attributes:[.font: CTFontCreateWithName("Helvetica" as CFString,14,nil), .foregroundColor:CGColor(red:1,green:0.98,blue:0.9,alpha:1)])
            ctx.textPosition = CGPoint(x:(i%5)*192+18,y:840-(i/5+1)*210+16)
            CTLineDraw(CTLineCreateWithAttributedString(label),ctx)
        }
        precondition(unique.count == names.count, "Distinct names retain distinct appearances")
        let cancelled = Task { @MainActor in await MountainFonster.portrait(seed:"cancelled-render") }
        cancelled.cancel()
        let cancelledImage = await cancelled.value
        precondition(cancelledImage == nil)
        let active = Task { @MainActor in await MountainFonster.portrait(seed:"active-render-cancellation") }
        let queued = Task { @MainActor in await MountainFonster.portrait(seed:"queued-render-cancellation") }
        try await Task.sleep(for: .milliseconds(25))
        queued.cancel(); active.cancel()
        let queuedImage = await queued.value
        _ = await active.value // cancellation can also arrive just after a still finishes
        precondition(queuedImage == nil)
        let recovered = await MountainFonster.portrait(seed:"after-render-cancellation")
        precondition(recovered?.width == 256, "Cancelling an active/queued request cannot poison the next one")
        let output = URL(fileURLWithPath:CommandLine.arguments[1]);let image=ctx.makeImage()!
        let dest=CGImageDestinationCreateWithURL(output as CFURL,UTType.png.identifier as CFString,1,nil)!
        CGImageDestinationAddImage(dest,image,nil);precondition(CGImageDestinationFinalize(dest))
        let data=try Data(contentsOf:output)
        let photo=MountainAvatarPhotos.prepare(data)!
        let src=CGImageSourceCreateWithData(photo as CFData,nil)!
        let small=CGImageSourceCreateImageAtIndex(src,0,nil)!
        precondition(max(small.width,small.height)<=256)
        precondition(MountainAvatarPhotos.prepare(Data(repeating:0,count:25_000_001))==nil)
        print("PASS: \(names.count) distinct fuzzy 3D name portraits, cached still reuse, cancellation; picker photo downsampling to 256px and oversized/corrupt input guard. Render time \(Date().timeIntervalSince(started))s.")
    }
}
