import XCTest

/// Walks timeline → stage → flip → page → dismiss, attaching named
/// screenshots at every beat (exported via xcresulttool during dev).
final class StageWalkTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testStageWalk() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestReset", "-uiTestSeedSamples"]
        app.launch()

        XCTAssertTrue(app.staticTexts["きっぷログ"].waitForExistence(timeout: 10))
        shot(app, "10-timeline-top")

        // Into the stage via the first plate.
        let firstRoute = app.staticTexts["新宿 → 箱根湯本"].firstMatch
        XCTAssertTrue(firstRoute.waitForExistence(timeout: 5))
        firstRoute.tap()

        let hero = app.otherElements["stage-hero"].firstMatch
        XCTAssertTrue(hero.waitForExistence(timeout: 5))
        sleep(1)
        shot(app, "11-stage-front")

        // Flip to the back face.
        hero.tap()
        sleep(1)
        shot(app, "12-stage-back")
        hero.tap()
        sleep(1)

        // Page to the next ticket.
        app.swipeLeft()
        sleep(1)
        shot(app, "13-stage-next")

        // Menu.
        app.buttons["stage-menu"].firstMatch.tap()
        sleep(1)
        shot(app, "14-stage-menu")
        // Close the menu by tapping elsewhere.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85)).tap()

        // Dismiss back to the shelf.
        app.buttons["stage-close"].firstMatch.tap()
        sleep(1)
        shot(app, "15-timeline-after")
    }

    @MainActor
    private func shot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
