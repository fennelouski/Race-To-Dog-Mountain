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
    func testTargetedActualCompletedShareLargestTextAgainAndFeedback() throws {
        launch()
        openActualCompleted()
        capture("Corrected source genuine saved 69 to 67 finish")
        app.buttons["share-result"].tap()
        let export = app.buttons["share-export"]
        XCTAssertTrue(awaitHittable(export, timeout: 30)); XCTAssertEqual(export.label, "Share replay GIF")
        capture("Corrected genuine transcript export ready")
        tree("Actual export bounds before Share")
        export.tap()
        let chooserControls = app.buttons.matching(NSPredicate(format: "label IN %@", ["Copy", "AirDrop", "Save to Files", "Add to Quick Note", "Open in", "Print"])).firstMatch
        let chooserObserved = awaitHittable(chooserControls, timeout: 12)
        tree("Actual OS Share presentation and bounds after wait")
        capture("Actual OS Share presentation after bounded wait")
        if chooserObserved {
            let close = app.buttons["Close"].firstMatch, cancel = app.buttons["Cancel"].firstMatch
            if awaitHittable(close, timeout: 2) { close.tap() }
            else if awaitHittable(cancel, timeout: 2) { cancel.tap() }
            else { app.swipeDown() }
        }
        let done = app.buttons["close-share"].firstMatch
        let doneHittable = awaitHittable(done)
        tree("Actual share dismissal bounds")
        if doneHittable {
            done.tap()
            XCTAssertTrue(awaitHittable(app.buttons["race-again"]))
            capture("Actual completed race after native Share dismissal")
        }
        app.terminate()
        launch(largest: true)
        let start = app.buttons["start-game"]
        XCTAssertTrue(start.isHittable && app.frame.contains(start.frame))
        capture("Largest text Play first viewport from genuine completed session")
        openActualCompleted()
        XCTAssertTrue(app.frame.contains(app.buttons["race-again"].frame) && app.frame.contains(app.buttons["share-result"].frame))
        capture("Largest text actual completed result and pinned actions")
        tree("Largest text actual completed action bounds")
        app.buttons["race-again"].tap()
        let fresh = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            self.app.buttons["tile-0"].exists && self.used() == 0 && !self.app.buttons["race-again"].exists
        }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [fresh], timeout: 8), .completed)
        capture("Largest text Race Again actual fresh board")
        app.terminate(); launch()
        XCTAssertEqual(app.buttons["start-game"].label, "Continue")
        app.buttons["start-game"].tap()
        XCTAssertTrue(app.buttons["tile-0"].waitForExistence(timeout: 5)); XCTAssertEqual(used(), 0)
        if legal() == nil { app.swipeUp() }
        guard let first = legal() else { return XCTFail("No actual opening replay move") }
        let humanChoice = first.identifier
        first.tap()
        let resolving = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", " takes ", "points")).firstMatch
        XCTAssertTrue(resolving.waitForExistence(timeout: 5))
        let observed = Date(); capture("Corrected actual computer resolving semantic feedback")
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND enabled == YES", "tile-")).count, 0)
        let marker = XCTAttachment(string: "Human choice: \(humanChoice)\nObserved computer label: \(resolving.label)\nObserved label date: \(observed)\nInput disabled during resolving.")
        marker.name = "Actual opening replay feedback observation"; marker.lifetime = .keepAlways; add(marker)
        tree("Corrected computer resolution actual tree")
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in self.legal() != nil && self.used() == 2 }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 8), .completed)
        capture("Actual replay returns legal input after computer resolution")
        XCTAssertTrue(chooserObserved, "Native OS chooser must be separately observed; actual GIF content remains independently verified")
        XCTAssertTrue(doneHittable, "Native Share preparation Done must have actual visible bounds before tap")
    }
}
