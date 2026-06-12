import XCTest

/// The viewfinder rehearsal (`-uiScreen viewfinder`): a scripted desk
/// scene drives the real guide chrome through seek → lock-on → hold so
/// every act can be eyeballed from simulator screenshots — there is no
/// camera in the simulator.
final class ViewfinderTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testViewfinderActs() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiScreen", "viewfinder"]
        app.launch()

        // Acts advance on tap, so shots anchor to state, not wall clock.

        // Act 1 — seeking: home window, breathing grips.
        usleep(600_000)
        shot(app, "30-viewfinder-seeking")

        // Act 2 — locked on: grips flown onto the ticket's corners.
        app.tap()
        usleep(900_000)
        shot(app, "31-viewfinder-locked")

        // Act 3 — hold: the vermilion loop drawing both ways.
        app.tap()
        usleep(600_000)
        shot(app, "32-viewfinder-hold")
    }

    @MainActor
    private func shot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
