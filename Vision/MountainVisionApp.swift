import SwiftUI

@main struct MountainVisionApp: App {
    var body: some Scene {
        WindowGroup("Tally Tangle") {
            MountainHome()
                .frame(minWidth: 760, minHeight: 660)
                .clipShape(RoundedRectangle(cornerRadius: 32))
                .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32))
        }
        .windowStyle(.plain)
        .defaultSize(width: 1180, height: 820)
        .windowResizability(.contentMinSize)
    }
}
