import XCTest

final class LaunchTests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    @MainActor func testLaunchShowsLiveResultsAndOpensSettings() {
        let app = XCUIApplication.fiscal()
        app.launch()
        XCTAssertTrue(app.waitForSections())
        XCTAssertTrue(app.buttons["Live Results"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts["President · Brazil"].waitForExistence(timeout: 10))
        capture(app, "live-results")
        #if !os(tvOS)
            XCTAssertTrue(app.openSettings())
            capture(app, "settings")
        #endif
    }

    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "\(name)-\(Int(app.windowWidth))pt"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
