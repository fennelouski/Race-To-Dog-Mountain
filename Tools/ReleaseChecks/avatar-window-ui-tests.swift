import XCTest
import UIKit

// Standalone UI-test target. Launches the installed simulator app with a fresh
// private QA save namespace; never uses the player's real saves or Game Center.
final class AvatarQA: XCTestCase {
    var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication(bundleIdentifier: "com.nathanfennel.RacetoDogMountain")
        app.launchArguments = ["-MountainUITests", "-MountainTestSession", UUID().uuidString,
            "-player1AI", "NO", "-player2AI", "NO", "-complexity", "4"]
    }
    func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func enterGame() {
        app.launch()
        XCTAssertTrue(app.buttons["start-game"].waitForExistence(timeout: 15))
        app.buttons["start-game"].tap()
        XCTAssertTrue(app.buttons["player-profile-0"].waitForExistence(timeout: 15))
    }
    func testLiveAvatarAndScoring() {
        enterGame()
        capture("game-avatar-initial")
        // Deliberate visual samples during and after the finite entrance.
        Thread.sleep(forTimeInterval: 0.4); capture("game-avatar-walking")
        Thread.sleep(forTimeInterval: 1.2); capture("game-avatar-ready")
        let card = app.buttons["player-profile-0"]
        let before = card.label
        let tile = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'tile-' AND enabled == true")).firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 5)); tile.tap()
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label != %@", before), object: card)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 5), .completed)
        capture("game-avatar-score-response")
        card.tap()
        XCTAssertTrue(app.buttons["save-profile"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1.5); capture("avatar-window-profile-96pt")
        app.buttons["save-profile"].tap()
        XCTAssertTrue(app.buttons["player-profile-0"].waitForExistence(timeout: 5))
    }
    func testAnimationOffStillShowsFuzzyAvatar() {
        app.launchArguments += ["-animationsEnabled", "NO"]
        enterGame()
        Thread.sleep(forTimeInterval: 2)
        capture("avatar-reduced-motion-ready")
        let screen = app.screenshot()
        let before = cropAvatar(screen)
        Thread.sleep(forTimeInterval: 0.5)
        let after = cropAvatar(app.screenshot())
        XCTAssertEqual(before, after, "The avatar must hold a still 3D pose with animations disabled")
    }
    func cropAvatar(_ screenshot: XCUIScreenshot) -> Data {
        let card = app.buttons["player-profile-0"].frame
        let cg = screenshot.image.cgImage!
        let scale = CGFloat(cg.width) / app.frame.width
        let rect = CGRect(x: (card.minX + 18) * scale, y: (card.minY + 18) * scale, width: 48 * scale, height: 48 * scale)
        return cg.cropping(to: rect)!.dataProvider!.data! as Data
    }
}
