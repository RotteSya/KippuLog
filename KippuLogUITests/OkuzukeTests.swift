import XCTest

/// The cover's two doors and the colophon page behind them.
final class OkuzukeTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Magazine → 収蔵帳 door → 誌面 door → 奥付 door → appearance stamp →
    /// tidy the samples away → the empty first page.
    @MainActor
    func testDoorsAndColophon() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestReset", "-uiTestSeedSamples"]
        app.launch()

        // The cover's left door opens the 収蔵帳.
        let albumDoor = app.buttons["masthead-album"].firstMatch
        XCTAssertTrue(albumDoor.waitForExistence(timeout: 8))
        albumDoor.tap()
        XCTAssertTrue(app.staticTexts["収蔵帳"].firstMatch.waitForExistence(timeout: 4))
        shot(app, "50-album-via-door")

        // The album's left door returns to the 誌面.
        app.buttons["album-magazine"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["きっぷログ"].firstMatch.waitForExistence(timeout: 4))

        // The right door opens the 奥付.
        app.buttons["masthead-okuzuke"].firstMatch.tap()
        let darkStamp = app.buttons["okuzuke-appearance-dark"].firstMatch
        XCTAssertTrue(darkStamp.waitForExistence(timeout: 4))
        shot(app, "51-okuzuke")

        // The night stamp presses in.
        darkStamp.tap()
        sleep(1)
        shot(app, "52-okuzuke-night")
        app.buttons["okuzuke-appearance-system"].firstMatch.tap()

        // Tidy the samples away; the sheet row flips to the invitation.
        app.buttons["okuzuke-tidy-samples"].firstMatch.tap()
        XCTAssertTrue(app.buttons["okuzuke-add-samples"].firstMatch.waitForExistence(timeout: 4))

        // Close the sheet — the magazine is an empty first page again.
        app.swipeDown(velocity: .fast)
        XCTAssertTrue(app.staticTexts["まだ切符がありません"].firstMatch.waitForExistence(timeout: 4))
        shot(app, "53-empty-after-tidy")
    }

    @MainActor
    private func shot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
