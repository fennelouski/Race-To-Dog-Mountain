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
        print("PASS: 4–14 grids, 4–14 thresholds, 288–1024pt viewports, compact/regular policies, height bounds, full-width 7×7, scroll target minimums. iPhone mini 7×7 tile: \(seven.tile)pt; large 14×14 in 600pt: \(fourteen.tile)pt.")
    }
}
