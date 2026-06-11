import XCTest

/// The remaining interaction surface: empty state, memo, edit sheet,
/// delete (ink dissolve), pinch-to-dismiss.
final class InteractionTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testEmptyStateInvitesSamples() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestReset"]
        app.launch()

        XCTAssertTrue(app.staticTexts["まだ切符がありません"].waitForExistence(timeout: 8))
        shot(app, "30-empty-state")

        app.buttons["サンプルの旅を見てみる"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["六月"].waitForExistence(timeout: 6))

        // The punch button opens the gate (import stage on simulator).
        app.buttons["punch-button"].firstMatch.tap()
        XCTAssertTrue(app.buttons["capture-library"].waitForExistence(timeout: 6))
        shot(app, "34-capture-import-stage")
        app.buttons["capture-close"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["六月"].waitForExistence(timeout: 6))
    }

    @MainActor
    func testMemoEditing() throws {
        let app = launchWithSamples()
        app.staticTexts["札幌 → 小樽"].firstMatch.tap()

        let memo = app.textViews["memo-field"].firstMatch
        let memoField = memo.exists ? memo : app.textFields["memo-field"].firstMatch
        XCTAssertTrue(memoField.waitForExistence(timeout: 6))
        memoField.tap()
        memoField.typeText("テスト追記。")

        let done = app.buttons["完了"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 4))
        done.tap()
        sleep(1)
        shot(app, "31-memo-edited")
    }

    @MainActor
    func testEditSheetUpdatesStation() throws {
        let app = launchWithSamples()
        scrollToEntry(app, "高山 → 名古屋").tap()

        XCTAssertTrue(app.otherElements["stage-hero"].waitForExistence(timeout: 6))
        app.buttons["stage-menu"].firstMatch.tap()
        app.buttons["編集"].firstMatch.tap()

        let from = app.textFields["field-from"].firstMatch
        XCTAssertTrue(from.waitForExistence(timeout: 6))
        // Select the whole station name, replace with an ASCII marker
        // (the sim's default keyboard can't type kanji via typeText).
        from.doubleTap()
        usleep(400_000)
        from.typeText("ABC")
        shot(app, "32-edit-sheet")

        app.buttons["保存"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["ABC → 名古屋"].waitForExistence(timeout: 6))
    }

    @MainActor
    func testDeleteDissolvesTicket() throws {
        let app = launchWithSamples()
        scrollToEntry(app, "京都 → 稲荷").tap()

        XCTAssertTrue(app.otherElements["stage-hero"].waitForExistence(timeout: 6))
        app.buttons["stage-menu"].firstMatch.tap()
        app.buttons["手放す"].firstMatch.tap()

        // Confirmation dialog.
        let confirm = app.scrollViews.otherElements.buttons["手放す"].firstMatch
        let fallback = app.buttons["手放す"].firstMatch
        if confirm.waitForExistence(timeout: 3) {
            confirm.tap()
        } else {
            fallback.tap()
        }
        sleep(2) // ink dissolve

        app.buttons["stage-close"].firstMatch.tap()
        sleep(1)
        XCTAssertFalse(app.staticTexts["京都 → 稲荷"].exists)
        shot(app, "33-after-delete")
    }

    @MainActor
    func testPinchToDismissStage() throws {
        let app = launchWithSamples()
        app.staticTexts["新宿 → 箱根湯本"].firstMatch.tap()
        XCTAssertTrue(app.otherElements["stage-hero"].waitForExistence(timeout: 6))

        app.pinch(withScale: 0.4, velocity: -1.2)
        // Back on the shelf: masthead is visible again.
        XCTAssertTrue(app.staticTexts["COLLECTED JOURNEYS"].waitForExistence(timeout: 6))
    }

    // MARK: Helpers

    /// Lazy timeline: swipe until the entry materializes and is tappable.
    @MainActor
    @discardableResult
    private func scrollToEntry(_ app: XCUIApplication, _ text: String) -> XCUIElement {
        let element = app.staticTexts[text].firstMatch
        var attempts = 0
        while !(element.exists && element.isHittable), attempts < 10 {
            app.swipeUp(velocity: .fast)
            attempts += 1
        }
        XCTAssertTrue(element.exists, "could not scroll to \(text)")
        return element
    }

    @MainActor
    private func launchWithSamples() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestReset", "-uiTestSeedSamples"]
        app.launch()
        XCTAssertTrue(app.staticTexts["きっぷログ"].waitForExistence(timeout: 10))
        return app
    }

    @MainActor
    private func shot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
