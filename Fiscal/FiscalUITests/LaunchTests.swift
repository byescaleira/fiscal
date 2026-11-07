import XCTest

final class LaunchTests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    @MainActor func testLaunchShowsTheFeedAndOpensSettings() {
        let app = XCUIApplication.fiscal()
        app.launch()
        XCTAssertTrue(app.waitForSections())
        for tab in ["Feed", "Votações", "Dinheiro", "Região", "Fiscalizar"] {
            XCTAssertTrue(app.buttons[tab].firstMatch.exists, tab)
        }
        capture(app, "feed")
        #if !os(tvOS)
            XCTAssertTrue(app.openSettings())
            capture(app, "settings")
        #endif
    }

    @MainActor func testANewInstallOpensStraightOnTheFirstTab() {
        let app = XCUIApplication.fiscal()
        app.launch()
        XCTAssertTrue(app.waitForSections())
        XCTAssertTrue(app.buttons["Feed"].firstMatch.isHittable)
        XCTAssertFalse(app.buttons["Escolher pessoas e causas"].exists)
        XCTAssertFalse(app.navigationBars["Meu apoio"].exists)
    }

    @MainActor func testTheFeedOpensTheLiveResults() {
        let app = XCUIApplication.fiscal()
        app.launch()
        XCTAssertTrue(app.waitForSections())
        let race = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Presidente"))
            .firstMatch
        XCTAssertTrue(race.waitForExistence(timeout: 15))
        race.tap()
        XCTAssertTrue(app.staticTexts["Presidente · Brasil"].waitForExistence(timeout: 10))
        capture(app, "live-results")
    }

    @MainActor func testFeedRowsAreButtonsAndTheEndIsReachableAtTheLargestTextSize() {
        let app = XCUIApplication.fiscal()
        app.launchArguments += [
            "-FiscalDataScenario", "normal",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
        ]
        app.launch()
        XCTAssertTrue(app.waitForSections())
        let filter = app.buttons["Relevante"]
        XCTAssertTrue(app.scrollDown(until: filter))
        filter.tap()
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Relevante"))
            .firstMatch
        XCTAssertTrue(app.scrollDown(until: row))
        capture(app, "feed-largest-text")
        let end = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "fatos"))
            .firstMatch
        XCTAssertTrue(app.scrollDown(until: end, attempts: 120))
        capture(app, "feed-end-largest-text")
    }

    @MainActor func testAFactCheckCardIsAsWideAsTheOtherCards() {
        let app = XCUIApplication.fiscal()
        app.launchArguments += ["-FiscalDataScenario", "normal", "-FiscalFollowScenario", "normal"]
        app.launch()
        XCTAssertTrue(app.waitForSections())
        let filter = app.buttons["Seguindo"].firstMatch
        XCTAssertTrue(app.scrollDown(until: filter))
        filter.tap()
        let other = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Você segue"))
            .firstMatch
        XCTAssertTrue(other.waitForExistence(timeout: 15))
        let width = other.frame.width
        let check = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Projeto Comprova"))
            .firstMatch
        XCTAssertTrue(app.scrollDown(until: check, attempts: 150))
        let window = app.windows.firstMatch
        let start = window.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.8))
        let end = window.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.6))
        var attempts = 0
        while check.frame.maxY > window.frame.maxY, attempts < 12 {
            start.press(forDuration: 0.1, thenDragTo: end)
            attempts += 1
        }
        XCTAssertTrue(check.isHittable)
        _ = XCTWaiter.wait(for: [XCTestExpectation(description: "scroll settles")], timeout: 2)
        XCTAssertEqual(check.frame.width, width, accuracy: 1)
        capture(app, "feed-fact-check")
    }

    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "\(name)-\(Int(app.windowWidth))pt"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
