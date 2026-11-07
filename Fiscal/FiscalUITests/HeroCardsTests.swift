import XCTest

final class HeroCardsTests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    @MainActor private func launched(_ link: String, arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication.fiscal()
        app.launchArguments +=
            [
                "-FiscalDataScenario", "normal", "-FiscalFollowScenario", "normal",
                "-fiscal.developer.openURL", link,
            ] + arguments
        app.launch()
        XCTAssertTrue(app.waitForSections())
        return app
    }

    @MainActor func testTheScoreboardAndTheComparisonOpenInTheCurrentMode() {
        let vote = launched("fiscal://vote/camara-18732026")
        let title = vote.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "1873")
        ).firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 30))
        capture(vote, "hero-vote")
        vote.terminate()
        let compare = launched("fiscal://compare?slugs=tabata-amaral,kim-kataguiri")
        XCTAssertTrue(compare.staticTexts["Tabata Amaral"].waitForExistence(timeout: 30))
        XCTAssertTrue(compare.staticTexts["Kim Kataguiri"].exists)
        capture(compare, "hero-compare")
    }

    @MainActor func testTheComparisonIsReadableAtTheLargestTextSize() {
        let app = launched(
            "fiscal://compare?slugs=tabata-amaral,kim-kataguiri",
            arguments: [
                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
            ])
        XCTAssertTrue(app.staticTexts["Tabata Amaral"].waitForExistence(timeout: 30))
        capture(app, "hero-compare-largest")
    }

    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "\(name)-\(Int(app.windowWidth))pt"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
