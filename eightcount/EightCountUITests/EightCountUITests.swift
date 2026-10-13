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

        // 7. My Takes → Compare
        app.buttons["More"].firstMatch.tap()
        let takesItem = app.buttons["My Takes (1)"].firstMatch
        waitFor(takesItem, 5)
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

        // 8. AI analysis (the test video has no people in it, so it must end
        //    with a friendly error — the point is that nothing crashes).
        app.buttons["Analyze"].firstMatch.tap()
        let analyze = app.buttons["Analyze my dancing"].firstMatch
        waitFor(analyze, 10)
        shot("11-analysis-start")
        analyze.tap()
        let finished = NSPredicate { _, _ in
            app.staticTexts["That didn't work"].exists || app.buttons["Analyze again"].exists
        }
        expectation(for: finished, evaluatedWith: nil)
        waitForExpectations(timeout: 240)
        shot("12-analysis-done")
    }
}
