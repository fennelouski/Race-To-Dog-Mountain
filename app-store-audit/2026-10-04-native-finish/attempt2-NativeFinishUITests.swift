import XCTest

final class NativeFinishUITests: XCTestCase {
    let app = XCUIApplication(bundleIdentifier: "com.nathanfennel.RacetoDogMountain")
    let session = "20B9DE9D-DA49-4833-B76E-A66F166FE132"
    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws {
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = "Actual native tree"; tree.lifetime = .keepAlways; add(tree)
        app.terminate()
    }
    func launch(largest: Bool = false) {
        app.launchArguments = ["-MountainUITests", "-MountainTestSession", session]
        if largest { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        XCTAssertTrue(app.staticTexts["mountain-private-qa"].waitForExistence(timeout: 10), "Private DEBUG UUID guard must be active before any interaction")
        XCTAssertTrue(app.buttons["start-game"].waitForExistence(timeout: 5))
    }
    func capture(_ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
    }
    func reveal(_ element: XCUIElement, attempts: Int = 8) {
        for _ in 0..<attempts { if element.exists && element.isHittable { return }; app.swipeUp() }
        XCTAssertTrue(element.exists && element.isHittable, "Actual control must be reachable: \(element)")
    }
    func used() -> Int {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "tile-", "used")).count
    }
    func legal() -> XCUIElement? {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND enabled == YES", "tile-")).allElementsBoundByIndex.first { $0.isHittable }
    }
    func closeLive() {
        reveal(app.buttons["close-game"], attempts: 1)
        app.buttons["close-game"].tap()
        let back = app.buttons["Back to games"]
        XCTAssertTrue(back.waitForExistence(timeout: 5)); back.tap()
        XCTAssertTrue(app.buttons["start-game"].waitForExistence(timeout: 5))
    }
    func testARealPhoneStartContinueCompletionExportAndEffects() throws {
        launch()
        XCTAssertEqual(app.buttons["start-game"].label, "Play")
        XCTAssertTrue(app.buttons["start-game"].isHittable)
        capture("Phone first viewport Play")
        reveal(app.buttons["game-options"]); app.buttons["game-options"].tap()
        let board = app.steppers["board-size-setting"]
        reveal(board)
        board.buttons.element(boundBy: 0).tap(); board.buttons.element(boundBy: 0).tap()
        let motion = app.switches["animations-setting"], haptics = app.switches["haptics-setting"]
        reveal(motion); reveal(haptics)
        XCTAssertEqual(motion.value as? String, "1"); XCTAssertEqual(haptics.value as? String, "1")
        motion.tap(); haptics.tap()
        app.buttons["Done"].firstMatch.tap(); app.terminate(); launch()
        reveal(app.buttons["game-options"]); app.buttons["game-options"].tap()
        reveal(motion); reveal(haptics)
        XCTAssertEqual(motion.value as? String, "0"); XCTAssertEqual(haptics.value as? String, "0")
        haptics.tap(); XCTAssertEqual(motion.value as? String, "0"); XCTAssertEqual(haptics.value as? String, "1")
        motion.tap()
        let speed = app.buttons["computer-speed-setting"]
        reveal(speed); speed.tap()
        let relaxed = app.buttons["Relaxed · 1.2 s"]
        XCTAssertTrue(relaxed.waitForExistence(timeout: 5)); relaxed.tap()
        capture("Independent saved effects and computer speed")
        app.buttons["Done"].firstMatch.tap()
        app.buttons["start-game"].tap()
        XCTAssertTrue(app.buttons["tile-0"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "tile-")).count, 16)
        capture("Real local starting board")
        if legal() == nil { app.swipeUp() }
        guard let first = legal() else { return XCTFail("No actual legal human move") }
        first.tap()
        let resolving = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", " takes ", "points")).firstMatch
        if resolving.waitForExistence(timeout: 2) {
            capture("Actual computer resolution")
            XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND enabled == YES", "tile-")).count, 0)
        }
        let after = Date().addingTimeInterval(8)
        while used() < 2 && Date() < after { Thread.sleep(forTimeInterval: 0.1) }
        XCTAssertGreaterThanOrEqual(used(), 2)
        let preserved = used()
        app.swipeDown(); closeLive(); app.terminate(); launch()
        XCTAssertEqual(app.buttons["start-game"].label, "Continue")
        capture("Cold launch Continue")
        app.buttons["start-game"].tap()
        XCTAssertTrue(app.buttons["tile-0"].waitForExistence(timeout: 5)); XCTAssertEqual(used(), preserved)
        var humanChoices = [String]()
        let deadline = Date().addingTimeInterval(75)
        while !app.buttons["race-again"].exists && Date() < deadline {
            if let move = legal() { humanChoices.append(move.identifier); move.tap() }
            else { Thread.sleep(forTimeInterval: 0.15) }
        }
        XCTAssertTrue(app.buttons["race-again"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["race-again"].isHittable && app.buttons["share-result"].isHittable)
        capture("Actual completed local game with pinned actions")
        let moves = XCTAttachment(string: humanChoices.joined(separator: "\n")); moves.name = "Actual human button choices after Continue"; moves.lifetime = .keepAlways; add(moves)
        app.buttons["share-result"].tap()
        XCTAssertTrue(app.buttons["share-export"].waitForExistence(timeout: 30))
        XCTAssertEqual(app.buttons["share-export"].label, "Share replay GIF")
        capture("Actual replay GIF ready")
        app.buttons["share-export"].tap()
        capture("Native share chooser without external destination")
        let shareTree = XCTAttachment(string: app.debugDescription); shareTree.name = "Native share chooser actual tree"; shareTree.lifetime = .keepAlways; add(shareTree)
        if app.buttons["Close"].firstMatch.exists { app.buttons["Close"].firstMatch.tap() }
        else if app.buttons["Cancel"].firstMatch.exists { app.buttons["Cancel"].firstMatch.tap() }
        else { app.swipeDown() }
        XCTAssertTrue(app.buttons["close-share"].waitForExistence(timeout: 5)); app.buttons["close-share"].tap()
        app.buttons["race-again"].tap()
        XCTAssertTrue(app.buttons["tile-0"].waitForExistence(timeout: 5)); XCTAssertEqual(used(), 0)
        capture("Race again starts an actual fresh board")
        closeLive()
    }
    func testBLargestTextFirstViewportAndActualSavedFinish() throws {
        launch(largest: true)
        let start = app.buttons["start-game"]
        XCTAssertTrue(start.isHittable && app.frame.contains(start.frame), "Largest text primary action must fit first viewport")
        capture("Largest text first viewport Continue")
        let finished = app.buttons["Finished games"]
        reveal(finished); finished.tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "finished-local-")).firstMatch
        reveal(row); row.tap()
        XCTAssertTrue(app.buttons["race-again"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["race-again"].isHittable && app.buttons["share-result"].isHittable)
        XCTAssertTrue(app.frame.contains(app.buttons["race-again"].frame) && app.frame.contains(app.buttons["share-result"].frame))
        capture("Largest text actual saved finish pinned actions")
        app.buttons["race-again"].tap()
        XCTAssertTrue(app.buttons["tile-0"].waitForExistence(timeout: 5)); XCTAssertEqual(used(), 0)
        capture("Largest text actual replay board")
    }
}
