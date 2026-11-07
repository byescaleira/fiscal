import XCTest

final class CardDestinationTests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    @MainActor private func launchedFeed() -> XCUIApplication {
        let app = XCUIApplication.fiscal()
        app.launchArguments += ["-FiscalDataScenario", "normal", "-FiscalFollowScenario", "normal"]
        app.launch()
        XCTAssertTrue(app.waitForSections())
        return app
    }

    @MainActor func testAPersonInAFeedCardOpensTheirProfile() {
        let app = launchedFeed()
        let person = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@ AND label CONTAINS %@", "Tabata Amaral", ":")
        ).firstMatch
        XCTAssertTrue(app.scrollDown(until: person, attempts: 20))
        person.tap()
        XCTAssertTrue(app.staticTexts["Ilustração do Fiscal"].waitForExistence(timeout: 15))
        capture(app, "card-person-profile")
    }

    @MainActor func testTheRestOfAFeedCardOpensItsContent() {
        let app = launchedFeed()
        let card = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "votou o PL")
        ).firstMatch
        XCTAssertTrue(app.scrollDown(until: card, attempts: 20))
        card.tap()
        let score = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Plenário")
        ).firstMatch
        let scoreCapitals = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "PLENÁRIO")
        ).firstMatch
        XCTAssertTrue(
            score.waitForExistence(timeout: 15) || scoreCapitals.waitForExistence(timeout: 5))
        capture(app, "card-content-vote")
    }

    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
