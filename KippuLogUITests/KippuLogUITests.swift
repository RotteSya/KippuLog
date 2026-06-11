import XCTest

final class KippuLogUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestReset"]
        app.launch()
        // Fresh install lands on the empty-magazine invitation.
        XCTAssertTrue(app.staticTexts["まだ切符がありません"].waitForExistence(timeout: 10))
    }
}
