import XCTest

/// 収蔵帳: pinch the magazine closed → the year album; open a mounted
/// mini straight into its stage; pinch the album open → the magazine.
final class AlbumTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAlbumPinchOpenAndThrough() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestReset", "-uiTestSeedSamples"]
        app.launch()
        XCTAssertTrue(app.staticTexts["きっぷログ"].waitForExistence(timeout: 10))

        // Pinch the magazine closed → the album.
        app.pinch(withScale: 0.5, velocity: -1.4)
        XCTAssertTrue(app.staticTexts["収蔵帳"].waitForExistence(timeout: 6))
        sleep(2)
        shot(app, "40-album")

        // A mounted mini opens its stage directly.
        let mini = app.descendants(matching: .any)["album-mini-新宿 → 箱根湯本"].firstMatch
        XCTAssertTrue(mini.waitForExistence(timeout: 5))
        mini.tap()
        XCTAssertTrue(app.otherElements["stage-hero"].waitForExistence(timeout: 6))
        sleep(1)
        shot(app, "41-stage-from-album")
        app.buttons["stage-close"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["収蔵帳"].waitForExistence(timeout: 6))

        // A month stamp jumps into the magazine at that month.
        let monthStamp = app.buttons["六月へ移動"].firstMatch
        if monthStamp.exists {
            monthStamp.tap()
            XCTAssertTrue(app.staticTexts["きっぷログ"].waitForExistence(timeout: 6))
        } else {
            // Pinch back out instead.
            app.pinch(withScale: 1.8, velocity: 1.6)
            XCTAssertTrue(app.staticTexts["きっぷログ"].waitForExistence(timeout: 6))
        }
        sleep(1)
        shot(app, "42-back-to-magazine")
    }

    @MainActor
    private func shot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
