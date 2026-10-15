import Foundation
@main enum BoardLayoutChecks {
    static func main() {
        for width in [288.0, 320, 343, 375, 500, 600, 760, 1024] {
            for size in 4...14 {
                for threshold in 4...14 {
                    for compact in [false, true] {
                        let layout = MountainBoardLayout(size: size, availableWidth: width, availableHeight: 500, compact: compact, scrollThreshold: threshold, minimumTile: 44)
                        assert(layout.tile > 0 && layout.extent.isFinite)
                        assert(layout.scrolls == (compact && size > threshold))
                        if !layout.scrolls { assert(layout.extent <= min(width, 500) + 0.001) }
                        else { assert(layout.tile >= 44) }
                    }
                }
            }
        }
        let seven = MountainBoardLayout(size: 7, availableWidth: 343, compact: true, scrollThreshold: 7, minimumTile: 44)
        assert(!seven.scrolls && abs(seven.extent - 343) < 0.001)
        let fourteen = MountainBoardLayout(size: 14, availableWidth: 760, availableHeight: 600, compact: false, scrollThreshold: 7, minimumTile: 44)
        assert(!fourteen.scrolls && fourteen.extent <= 600)
        var events: [MountainMoveFeedback] = []
        var previousCount = 0
        for points in 0...196 {
            let event = MountainMoveFeedback(id: points, tile: 0, player: points % 2, points: points, maximum: 196)
            assert(event.particleCount >= previousCount && event.particleCount <= 48)
            previousCount = event.particleCount
            events = event.adding(to: events)
            assert(events.count <= 4 && events.reduce(0, { $0 + $1.particleCount }) <= 192)
            for index in 0..<event.particleCount {
                let first = MountainPointParticle.sample(index: index, count: event.particleCount, progress: 0, startX: 100, startY: 500, endX: 40, endY: 100, spread: event.spread)
                let last = MountainPointParticle.sample(index: index, count: event.particleCount, progress: 1, startX: 100, startY: 500, endX: 40, endY: 100, spread: event.spread)
                let mid = MountainPointParticle.sample(index: index, count: event.particleCount, progress: 0.5, startX: 100, startY: 500, endX: 40, endY: 100, spread: event.spread)
                assert(first.x == 100 && first.y == 500 && first.opacity == 0)
                assert(abs(last.x - 40) < 0.000001 && abs(last.y - 100) < 0.000001 && last.opacity == 0)
                assert(mid.x.isFinite && mid.y.isFinite && (0...1).contains(mid.opacity))
            }
        }
        let retired = events[0], newer = MountainMoveFeedback(id: retired.id, tile: 1, player: 1, points: 12, maximum: 196)
        events = newer.adding(to: events)
        events = MountainMoveFeedback.finishing(retired.token, in: events)
        assert(events.contains(where: { $0.token == newer.token }), "Old game completion cannot remove a reused move number")
        let completed = events[0]
        events = MountainMoveFeedback.finishing(completed.token, in: events)
        assert(!events.contains(where: { $0.token == completed.token }) && events.contains(where: { $0.token == newer.token }))
        print("PASS: individual point paths start at cell and finish at score; quantity/spread scale; 48 points/event and 192 total cap; stale completion cannot remove a newer event.")
        print("PASS: 4–14 grids, 4–14 thresholds, 288–1024pt viewports, compact/regular policies, height bounds, full-width 7×7, scroll target minimums. iPhone mini 7×7 tile: \(seven.tile)pt; large 14×14 in 600pt: \(fourteen.tile)pt.")
    }
}
