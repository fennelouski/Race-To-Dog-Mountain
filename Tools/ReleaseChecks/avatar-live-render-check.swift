import Foundation
import ImageIO
import UniformTypeIdentifiers

@main struct AvatarLiveRenderChecks {
    @MainActor static func main() async throws {
        let directory = URL(fileURLWithPath: CommandLine.arguments[1])
        let scene = try await MountainLiveFonsterScene.make(seed: "Nathan", side: 192)
        var activity = MountainAvatarActivity(); activity.isTurn = true
        var distinct: Set<Data> = []
        for (name, cue, progress) in [("entry-outside", MountainAvatarCue.enter, Float(0)),
                                      ("entry-walking", .enter, 0.55), ("ready", .enter, 1),
                                      ("score-hop", .score, 0.5), ("winner", .win, 0.3)] {
            let image = try await scene.render(.sample(activity: activity, cue: cue, progress: progress))
            precondition(image.width == 192 && image.height == 192)
            distinct.insert(image.dataProvider!.data! as Data)
            let url = directory.appendingPathComponent(name + ".png")
            let output = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
            CGImageDestinationAddImage(output, image, nil); precondition(CGImageDestinationFinalize(output))
        }
        precondition(distinct.count == 5, "The native 3D geometry must actually move, not reuse a still")
        let cancelled = Task { @MainActor in try await scene.render(.init()) }; cancelled.cancel()
        do { _ = try await cancelled.value; preconditionFailure("Cancelled frame published") } catch is CancellationError {}
        _ = try await scene.render(.init())
        print("PASS: genuine live 3D warm-up, five distinct entrance/depth/hop frames, cancelled-frame rejection and subsequent renderer recovery; no device camera or AR session.")
    }
}
