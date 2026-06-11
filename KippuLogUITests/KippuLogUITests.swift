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
        XCTAssertTrue(app.staticTexts["きっぷログ"].waitForExistence(timeout: 10))
    }
}
