// Appended to a temporary copy of the actual views by check-pinned-layout.py.
// Score fixtures alter only displayed numbers, never game data or saved scores.
@MainActor final class LayoutProbe { static var scoreFixture: Int?; static var events: [MountainMoveFeedback] = []; var frame: CGRect? }
private struct ProbeMarker: View {
    init(_ probe: LayoutProbe, _ frame: CGRect) { probe.frame = frame }
    var body: some View { Color.clear }
}
@main struct PinnedLayoutRenderChecks {
    @MainActor static func main() throws {
        _ = NSApplication.shared
        var rows: [[String: Any]] = []
        let folder = URL(fileURLWithPath: CommandLine.arguments[1])
        for (width,height) in [(375.0,812.0),(834.0,1194.0),(1200.0,900.0)] {
            for type in [DynamicTypeSize.large, .accessibility5] {
                var baseline: CGRect?
                for count in [0,1,4,12,24,40] {
                    LayoutProbe.scoreFixture = count == 24 ? 9999 : count == 40 ? 10000 : nil
                    LayoutProbe.events = (0..<(count == 0 ? 0 : 4)).map { MountainMoveFeedback(id: $0, tile: $0, player: $0 % 2, points: 49, maximum: 49) }
                    var game = MountainGame(size: 7, values: Array(1...49), firstPlayer: 0, startingLine: 0)
                    for _ in 0..<count { if let tile = game.legalMoves.max(by: { game.tiles[$0].value < game.tiles[$1].value }) { game.play(tile) } }
                    var saved = SavedMountainGame(size: 7, names: [String(repeating: "W", count: count > 0 ? 50 : 1),"Second"], computers: [false,false], difficulty: .level1, adjustment: 0)
                    saved.game = game; saved.history = nil
                    let probe = LayoutProbe()
                    let content = MountainGameView(size: 7, names: saved.names, computers: saved.computers, difficulty: .level1, adjustment: 0, saved: saved)
                        .environment(\.dynamicTypeSize, type).environment(\.scenePhase, .active)
                        .frame(width: width, height: height)
                        .overlayPreferenceValue(MountainMoveAnchors.self) { anchors in GeometryReader { proxy in
                            if let tile = anchors[.tile(0)] { ProbeMarker(probe, proxy[tile]) }
                        } }
                    let renderer = ImageRenderer(content: content); renderer.scale = 1
                    guard renderer.cgImage != nil, let frame = probe.frame else { fatalError("No actual board frame rendered") }
                    if let baseline { precondition(abs(baseline.minY-frame.minY) < 0.01 && abs(baseline.width-frame.width) < 0.01 && abs(baseline.minX-frame.minX) < 0.01, "Board reflowed") }
                    else { baseline = frame }
                    rows.append(["width":width,"height":height,"type":String(describing:type),"moves":game.moves,"scores":game.scores,"scoreDisplayFixture":LayoutProbe.scoreFixture ?? -1,"concurrentEffects":LayoutProbe.events.count,"tileX":frame.minX,"tileY":frame.minY,"tileWidth":frame.width])

                }
            }
        }
        try JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted,.sortedKeys]).write(to: folder.appendingPathComponent("pinned-render-layouts.json"))
        print("PASS: actual GameView tile frame unchanged across score/profile growth at 375/834/1200 widths and Large/AX5 Dynamic Type")
    }
}
