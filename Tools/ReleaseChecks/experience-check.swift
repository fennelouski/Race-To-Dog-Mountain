import Foundation
@main struct ExperienceChecks {
    static func main() throws {
        var lesson = MountainTutorial()
        let initial = lesson.game.tiles.map(\.value)
        precondition(!lesson.choose(0), "Off-row tutorial action must be rejected")
        for step in 0..<4 {
            precondition(lesson.step == step && !lesson.finished)
            precondition(lesson.choose(lesson.game.legalMoves[0]))
            precondition(lesson.game.isValid && lesson.game.moves == step + 1)
        }
        precondition(lesson.finished && !lesson.choose(lesson.game.legalMoves[0]))
        lesson.navigate(to: 0); precondition(lesson.game.tiles.map(\.value) == initial)
        lesson.navigate(to: 4); precondition(lesson.finished)
        lesson.navigate(to: 1); precondition(lesson.choose(lesson.game.legalMoves.last!))
        precondition(lesson.step == 2 && !lesson.canGoForward, "Changing an earlier choice must invalidate later steps")
        lesson.navigate(to: 4); precondition(lesson.step == 2)
        var pass = SavedMountainGame(size: 4, names: ["A", "B"], computers: [false,false], difficulty: .level1, adjustment: 0)
        precondition(!pass.hasScore && pass.category == .passAndPlay)
        pass.game.play(pass.game.legalMoves[0]); precondition(pass.hasScore)
        let ai = SavedMountainGame(size: 4, names: ["A", "B"], computers: [false,true], difficulty: .level4, adjustment: 0)
        precondition(!ai.hasScore && ai.category == .ai && ai.title.contains("Theo (4)"))
        for profile in ComputerDifficulty.allCases { precondition(profile.displayName == "\(profile.name) (\(profile.rawValue + 1))") }
        let legacy = Data("{\"A\":{\"displayName\":\"Nathan\",\"symbol\":\"leaf.fill\"}}".utf8)
        let profile = MountainHumanProfile.read(identity: "A", data: legacy)
        precondition(profile.displayName == "Nathan" && profile.resolvedStyle == "symbol")
        precondition(MountainHumanProfile.read(identity: "B", data: legacy).resolvedStyle == "fonster")
        let updated = MountainHumanProfile.updating(identity: "A", displayName: "Nathan", symbol: "person.fill", data: legacy, avatarStyle: "photo", photoID: UUID().uuidString)!
        precondition(MountainHumanProfile.read(identity: "A", data: updated).resolvedStyle == "photo")
        precondition(MountainHumanProfile.updating(identity: "A", displayName: "A", symbol: "person.fill", data: updated, avatarStyle: "photo", photoID: "../../bad") == nil)
        let formatter = ISO8601DateFormatter()
        let noon = MountainSky(date: formatter.date(from: "2026-06-15T12:00:00Z")!, timeZone: TimeZone(secondsFromGMT: 0)!)
        let night = MountainSky(date: formatter.date(from: "2026-06-15T00:00:00Z")!, timeZone: TimeZone(secondsFromGMT: 0)!)
        precondition(noon.daylight == 1 && night.daylight == 0 && noon.sunProgress == 0.5)
        for zone in TimeZone.knownTimeZoneIdentifiers {
            let sky = MountainSky(date: Date(timeIntervalSince1970: 1792000000), timeZone: TimeZone(identifier: zone)!)
            precondition((0...1).contains(sky.daylight) && (0...1).contains(sky.sunProgress))
        }
        print("PASS: tutorial actions, legal branching/back navigation and isolation; scoreless filtering/categories; all 16 AI name levels; legacy/avatar/photo profile decoding and path validation; local-time decorative sky bounds.")
    }
}
