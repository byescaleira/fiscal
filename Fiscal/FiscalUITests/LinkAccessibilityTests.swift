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
}
