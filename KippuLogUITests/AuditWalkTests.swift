import XCTest

/// Design-audit walk: every screen, every state, named screenshots.
/// Temporary aid for the polish pass — exported via xcresulttool.
final class AuditWalkTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testFullAuditWalk() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestReset", "-uiTestSeedSamples"]
        app.launch()

        XCTAssertTrue(app.staticTexts["きっぷログ"].waitForExistence(timeout: 10))

        // Stage — photo ticket (first entry is a photo-backed sample? tap first route).
        let firstRoute = app.staticTexts["新宿 → 箱根湯本"].firstMatch
        XCTAssertTrue(firstRoute.waitForExistence(timeout: 5))
        firstRoute.tap()
        let hero = app.otherElements["stage-hero"].firstMatch
        XCTAssertTrue(hero.waitForExistence(timeout: 5))
        sleep(2)
        shot(app, "20-stage")

        // Edit sheet.
        app.buttons["stage-menu"].firstMatch.tap()
        sleep(1)
        let edit = app.buttons["編集"].firstMatch
        if edit.waitForExistence(timeout: 3) {
            edit.tap()
            sleep(1)
            shot(app, "21-edit-sheet")
            app.swipeDown(velocity: .fast)
            sleep(1)
        }

        // Photo inspector (hero tap) — only when the ticket has a photo.
        hero.tap()
        sleep(1)
        shot(app, "22-inspector-or-stage")
        // Drag down to dismiss inspector if it opened.
        app.swipeDown(velocity: .fast)
        sleep(1)

        app.buttons["stage-close"].firstMatch.tap()
        sleep(1)

        // Scroll the timeline to see mid-list rhythm + colophon.
        app.swipeUp()
        sleep(1)
        shot(app, "23-timeline-mid")
        app.swipeUp(); app.swipeUp(); app.swipeUp()
        sleep(1)
        shot(app, "24-timeline-colophon")
    }

    @MainActor
    private func shot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
