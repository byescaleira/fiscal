import XCTest

final class LinkAccessibilityTests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    @MainActor func testMandateActsAreLinksAndQuotaBarsNameTheirState() {
        let app = XCUIApplication.fiscal()
        app.launchArguments += [
            "-FiscalDataScenario", "normal", "-fiscal.developer.openURL", "fiscal://money",
        ]
        app.launch()
        XCTAssertTrue(app.waitForSections())

        let act = app.links.matching(NSPredicate(format: "label CONTAINS %@", "Subsídio"))
            .firstMatch
        XCTAssertTrue(app.scrollDown(until: act))

        let quotaBar = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "São Paulo"))
            .matching(NSPredicate(format: "value CONTAINS %@", "R$"))
            .firstMatch
        XCTAssertTrue(app.scrollDown(until: quotaBar))
    }

    @MainActor func testMySupportRowsAreButtonsAtTheLargestTextSize() {
        let app = XCUIApplication.fiscal()
        app.launchArguments += [
            "-FiscalDataScenario", "normal",
            "-FiscalSupportScenario", "people=tabata-amaral;causes=saude",
            "-fiscal.developer.openURL", "fiscal://support",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
        ]
        app.launch()
        XCTAssertTrue(app.waitForSections())
        let delete = app.buttons["Apagar meu apoio"]
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Votação"))
            .firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "my-support-largest-text"
        shot.lifetime = .keepAlways
        add(shot)
        XCTAssertTrue(app.scrollDown(until: delete, attempts: 30))
    }
}
