import XCTest

final class NativeFinishUITests: XCTestCase {
    let app = XCUIApplication(bundleIdentifier: "com.nathanfennel.RacetoDogMountain")
    let session = "ABEA31B0-4471-48C8-8613-925A357E3BD3"
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
    func awaitHittable(_ element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            element.exists && element.isHittable && !element.frame.isEmpty && element.frame.minX >= 0 && element.frame.minY >= 0
        }, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
    func tree(_ name: String) {
        let bounds = app.buttons.allElementsBoundByIndex.filter { $0.exists }.map { "\($0.identifier) | \($0.label) | \($0.frame) | hittable=\($0.isHittable)" }.joined(separator: "\n")
        let attachment = XCTAttachment(string: app.debugDescription + "\nCURRENT BUTTON BOUNDS\n" + bounds)
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func openActualCompleted() {
        let finished = app.buttons["Finished games"]
        reveal(finished); finished.tap()
        let row = app.buttons["finished-local-C7D6F881-5AB4-4BDB-84BB-3340310BB357"]
        reveal(row); row.tap()
        XCTAssertTrue(awaitHittable(app.buttons["race-again"]))
        XCTAssertTrue(awaitHittable(app.buttons["share-result"]))
        XCTAssertEqual(used(), 16, "Must reuse genuine actual completed 16-move transcript")
    }
    func testActualNativeChooserAndObservedDismissalOnly() throws {
        launch(); openActualCompleted()
        app.buttons["share-result"].tap()
        let export = app.buttons["share-export"]
        XCTAssertTrue(awaitHittable(export, timeout: 30)); export.tap()
        let chooser = app.otherElements["ActivityListView"]
        XCTAssertTrue(awaitHittable(chooser, timeout: 12))
        let copy = chooser.cells.matching(NSPredicate(format: "label == %@", "Copy")).firstMatch
        XCTAssertTrue(awaitHittable(copy), "Observe actual native Cell without selecting a destination")
        capture("Actual native OS chooser confirmed by ActivityListView and Cell")
        let backdrop = app.otherElements["PopoverDismissRegion"]
        XCTAssertTrue(awaitHittable(backdrop), "Native semantic dismiss popup region must exist and be hittable")
        tree("Actual OS chooser and dismissal button bounds")
        let bounds = XCTAttachment(string: "ActivityListView: \(chooser.frame)\nCopy Cell: \(copy.frame), hittable=\(copy.isHittable)\nPopoverDismissRegion: \(backdrop.frame), hittable=\(backdrop.isHittable)")
        bounds.name = "Actual observed native popup dismissal bounds"; bounds.lifetime = .keepAlways; add(bounds)
        XCTAssertFalse(chooser.frame.contains(CGPoint(x: backdrop.frame.midX, y: backdrop.frame.midY)), "Observed native dismissal center must be outside the chooser")
        backdrop.tap()
        let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in !chooser.exists }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 8), .completed)
        let done = app.buttons["close-share"].firstMatch
        XCTAssertTrue(awaitHittable(done)); tree("Actual native preparation Done now hittable")
        done.tap()
        XCTAssertTrue(awaitHittable(app.buttons["race-again"]))
        XCTAssertTrue(awaitHittable(app.buttons["share-result"]))
        XCTAssertEqual(used(), 16)
        capture("Actual completed race after observed native chooser and Done dismissals")
    }
}
