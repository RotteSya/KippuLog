import XCTest

/// End-to-end capture: punch button → auto-import a synthetic ticket
/// photo → gate ceremony → OCR/parse → confirm → save → shelf.
final class CaptureWalkTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCaptureImportToShelf() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTestReset", "-uiTestSeedSamples",
            "-uiTestImport", "/tmp/kippu_test_ticket.png",
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["きっぷログ"].waitForExistence(timeout: 10))

        // -uiTestImport auto-opens the gate; the ceremony plays (~3s).
        usleep(2_100_000)
        shot(app, "20-gate-pass")

        // Confirm sheet: parsed plate + fields.
        let save = app.buttons["confirm-save"].firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 12))
        sleep(2)
        shot(app, "21-confirm")

        // The parser must have read the synthetic ticket.
        XCTAssertTrue(app.staticTexts["新大阪"].firstMatch.exists
                      || app.textFields.matching(NSPredicate(format: "value CONTAINS '新大阪'")).count > 0)

        save.tap()

        // Back on the shelf — the new journey is in the magazine, shown as
        // the real photographed ticket (a matted card, not a rendered plate).
        let entry = app.staticTexts["東京 → 新大阪"].firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 8))
        sleep(2)
        shot(app, "22-timeline-with-new")

        // Open its stage — the hero is the real photo.
        entry.tap()
        let hero = app.otherElements["stage-hero"].firstMatch
        XCTAssertTrue(hero.waitForExistence(timeout: 6))
        sleep(2)
        shot(app, "23-stage-photo-hero")

        // Tap the photo → full-screen zoomable inspector.
        hero.tap()
        let closeButton = app.buttons["inspector-close"].firstMatch
        XCTAssertTrue(closeButton.waitForExistence(timeout: 6))
        sleep(1)
        shot(app, "24-photo-inspector")
        closeButton.tap()
        XCTAssertTrue(hero.waitForExistence(timeout: 6))
    }

    /// The angled-on-clutter fixture: flatten (or subject lift) must hand
    /// back a clean borderless ticket, and the route must still parse.
    @MainActor
    func testAngledPhotoBecomesCleanObject() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTestReset",
            "-uiTestImport", "/tmp/kippu_test_angled.png",
        ]
        app.launch()

        let save = app.buttons["confirm-save"].firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 18))
        sleep(2)
        shot(app, "25-confirm-angled")
        XCTAssertTrue(app.textFields.matching(NSPredicate(format: "value CONTAINS '新大阪'")).count > 0
                      || app.staticTexts["新大阪"].firstMatch.exists)
        save.tap()

        let entry = app.staticTexts["東京 → 新大阪"].firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 8))
        sleep(2)
        shot(app, "26-timeline-angled")
    }

    @MainActor
    private func shot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
