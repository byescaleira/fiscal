import XCTest

final class LaunchTests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    @MainActor func testLaunchShowsFollowingAndOpensSettings() {
        let app = XCUIApplication.fiscal()
        app.launch()
        XCTAssertTrue(app.waitForSections())
        for tab in ["Seguindo", "Hoje", "Votações", "Dinheiro", "Fiscalizar"] {
            XCTAssertTrue(app.buttons[tab].firstMatch.exists, tab)
        }
        capture(app, "following")
        #if !os(tvOS)
            XCTAssertTrue(app.openSettings())
            capture(app, "settings")
        #endif
    }

    @MainActor func testANewInstallOpensStraightOnTheFirstTab() {
        let app = XCUIApplication.fiscal()
        app.launch()
        XCTAssertTrue(app.waitForSections())
        XCTAssertTrue(app.buttons["Seguindo"].firstMatch.isHittable)
        XCTAssertFalse(app.buttons["Escolher pessoas e causas"].exists)
        XCTAssertFalse(app.navigationBars["Meu apoio"].exists)
    }

    @MainActor func testTodayOpensTheLiveResults() {
        let app = XCUIApplication.fiscal()
        app.launch()
        XCTAssertTrue(app.waitForSections())
        app.showToday()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Apuração")).firstMatch
            .tap()
        XCTAssertTrue(app.staticTexts["Presidente · Brasil"].waitForExistence(timeout: 10))
        capture(app, "live-results")
    }

    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "\(name)-\(Int(app.windowWidth))pt"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
