import XCTest

/// Clicks through the main features on a simulator, taking screenshots.
/// Runs on GitHub's Macs (see .github/workflows/eightcount-ios-build.yml),
/// which pass in a generated test video via SEED_VIDEO.
final class EightCountUITests: XCTestCase {
    private var shotsDir: String {
        ProcessInfo.processInfo.environment["SHOTS_DIR"] ?? NSTemporaryDirectory()
    }

    override func setUp() {
        continueAfterFailure = false
    }

    /// Saves a screenshot as <SHOTS_DIR>/<name>.png and attaches it to the result.
    private func shot(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        try? screenshot.pngRepresentation.write(
            to: URL(fileURLWithPath: shotsDir).appendingPathComponent("\(name).png"))
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func waitFor(_ element: XCUIElement, _ seconds: TimeInterval = 15,
                         file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: seconds),
                      "Not found: \(element)", file: file, line: line)
    }

    func testMainFlow() throws {
        let video = try XCTUnwrap(ProcessInfo.processInfo.environment["SEED_VIDEO"],
                                  "SEED_VIDEO is not set")
        let app = XCUIApplication()
        app.launchArguments = ["-seedDemo"]
        app.launchEnvironment["SEED_VIDEO"] = video
        app.launch()

        // 1. Project list
        let demo = app.staticTexts["Demo"].firstMatch
        waitFor(demo)
        shot("01-project-list")

        // 1b. New Project sheet (then cancel)
        app.buttons["New project"].firstMatch.tap()
        let cancel = app.buttons["Cancel"].firstMatch
        waitFor(cancel, 5)
        sleep(1)
        shot("01b-new-project")
        cancel.tap()
        waitFor(demo, 5)

        // 2. Practice screen with the video
        demo.tap()
        let play = app.buttons["Play"].firstMatch
        waitFor(play)
        waitFor(app.buttons["Loop 8-count 2"], 20)   // 8-count list appears once the video is loaded
        shot("02-practice")

        // 3. Play for a moment, then pause
        play.tap()
        sleep(3)
        shot("03-playing")
        app.buttons["Pause"].firstMatch.tap()

        // 4. Slow down + mirror
        app.buttons["Speed 0.5×"].firstMatch.tap()
        app.buttons["Mirror off"].firstMatch.tap()
        shot("04-half-speed-mirrored")

        // 5. Loop one 8-count
        app.buttons["Loop 8-count 2"].tap()
        sleep(3)
        shot("05-loop-8-count")

        // 6. Notes for 8-count 1
        app.buttons["Edit notes for 8-count 1"].firstMatch.tap()
        let done = app.buttons["Done"].firstMatch
        waitFor(done)
        shot("06-notes")
        done.tap()
        // Let the sheet finish closing before using the toolbar menu.
        XCTAssertTrue(done.waitForNonExistence(timeout: 10), "Notes sheet didn't close")
        sleep(1)

        // 7. My Takes → Compare
        let takesItem = app.buttons["My Takes (1)"].firstMatch
        let more = app.buttons["More"].firstMatch
        let hittable = NSPredicate(format: "exists == true AND hittable == true")
        for attempt in 0..<3 {
            if more.exists && more.isHittable { more.tap() }
            let wait = XCTNSPredicateExpectation(predicate: hittable, object: takesItem)
            if XCTWaiter().wait(for: [wait], timeout: 5) == .completed { break }
            // Menu didn't open properly: close whatever is open and retry.
            if attempt < 2 { app.tap(); sleep(1) }
        }
        XCTAssertTrue(takesItem.isHittable, "My Takes menu item not tappable")
        takesItem.tap()
        let takeRow = app.cells.firstMatch
        waitFor(takeRow)
        shot("07-takes")
        takeRow.tap()

        let close = app.buttons["Close"].firstMatch
        waitFor(close, 20)
        sleep(2)
        shot("08-compare")
        app.buttons["Play"].firstMatch.tap()
        sleep(3)
        shot("09-compare-playing")

        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(2)
        shot("10-compare-landscape")
        XCUIDevice.shared.orientation = .portrait
        sleep(2)

        // Ghost mode (tutorial see-through over you, auto-aligned)
        let ghost = app.buttons["Ghost"].firstMatch
        if ghost.waitForExistence(timeout: 5) {
            ghost.tap()
            sleep(3)
            shot("10b-ghost")
            app.buttons["Side by side"].firstMatch.tap()
            sleep(1)
        }

        // Coach mode from the saved (seeded) analysis: issue shown on the video
        let showIssues = app.buttons["Show issues"].firstMatch
        if showIssues.waitForExistence(timeout: 5) {
            showIssues.tap()
            sleep(4)
            shot("10c-coach-1")
            let next = app.buttons["Next issue"].firstMatch
            if next.waitForExistence(timeout: 3) {
                next.tap()
                sleep(4)
                shot("10d-coach-2")
            }
            let closeCoach = app.buttons["Close coach"].firstMatch
            if closeCoach.exists { closeCoach.tap(); sleep(1) }
        }

        // 7b. Save the take to Photos with the song (the TikTok export)
        let saveVideo = app.buttons["Save video"].firstMatch
        if saveVideo.waitForExistence(timeout: 5) {
            saveVideo.tap()
            let saveToPhotos = app.buttons["Save to Photos"].firstMatch
            waitFor(saveToPhotos, 10)
            sleep(1)
            shot("10e-save-sheet")
            saveToPhotos.tap()
            // If iOS still asks for permission, allow it.
            let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
            for label in ["Allow", "Allow Access", "OK"] {
                let button = springboard.buttons[label]
                if button.waitForExistence(timeout: 3) { button.tap(); break }
            }
            waitFor(app.staticTexts["Saved to Photos"].firstMatch, 180)
            shot("10f-saved")
            let done = app.buttons["Done"].firstMatch
            if done.exists { done.tap() } else { app.swipeDown() }
            sleep(1)
        }

        // 8. AI analysis (the test video has no people in it, so it must end
        //    with a friendly error — the point is that nothing crashes).
        app.buttons["Analyze"].firstMatch.tap()
        // The seeded take already has a report, so the sheet opens on the results.
        let again = app.buttons["Analyze again"].firstMatch
        let first = app.buttons["Analyze my dancing"].firstMatch
        let appeared = NSPredicate { _, _ in again.exists || first.exists }
        expectation(for: appeared, evaluatedWith: nil)
        waitForExpectations(timeout: 15)
        sleep(1)
        shot("11-analysis-results")
        (again.exists ? again : first).tap()
        // The test video has no person in it, so a real run must end with the
        // friendly error — the point is that nothing crashes.
        waitFor(app.staticTexts["That didn't work"].firstMatch, 240)
        shot("12-analysis-done")
    }
}
