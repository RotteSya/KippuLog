import XCTest

/// The opening ceremony: the machine prints the 見本, the invitation
/// appears, and both exits land where they promise.
final class WelcomeCeremonyTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// 「最初の一枚を撮る」 — the specimen dives into the gate and the
    /// capture flow opens.
    @MainActor
    func testWelcomeIntoCapture() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestReset", "-uiTestWelcome"]
        app.launch()

        let capture = app.buttons["welcome-capture"].firstMatch
        XCTAssertTrue(capture.waitForExistence(timeout: 12))
        // The ceremony must settle before the button accepts touches.
        let settled = expectation(description: "CTA hittable")
        Task {
            while !capture.isHittable { try? await Task.sleep(for: .milliseconds(200)) }
            settled.fulfill()
        }
        wait(for: [settled], timeout: 12)
        shot(app, "30-welcome-settled")

        capture.tap()
        // The gate opens (simulator has no camera → import stage shows).
        let close = app.buttons["capture-close"].firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 8))
        shot(app, "31-welcome-into-capture")

        // Never again: relaunch shows the shelf straight away.
        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertFalse(app.buttons["welcome-capture"].waitForExistence(timeout: 3))
    }

    /// 「まずは見てまわる」 — lights up on the empty first page.
    @MainActor
    func testWelcomeIntoBrowse() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestReset", "-uiTestWelcome"]
        app.launch()

        let later = app.buttons["welcome-later"].firstMatch
        XCTAssertTrue(later.waitForExistence(timeout: 12))
        // The 朱 CTA turning hittable is the "scene settled" signal; the
        // quiet text button then takes a coordinate tap (XCUI misreports
        // hittability for small plain-text buttons over the engine).
        let capture = app.buttons["welcome-capture"].firstMatch
        let settled = expectation(description: "CTA hittable")
        Task {
            while !capture.isHittable { try? await Task.sleep(for: .milliseconds(200)) }
            settled.fulfill()
        }
        wait(for: [settled], timeout: 12)

        later.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let emptyLine = app.staticTexts["まだ切符がありません"].firstMatch
        XCTAssertTrue(emptyLine.waitForExistence(timeout: 6))
        sleep(1)
        shot(app, "32-welcome-into-empty")
    }

    @MainActor
    private func shot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
