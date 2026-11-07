import XCTest

final class VoteDetailTests: XCTestCase {
    private let nominal = "camara-18732026"
    private let voice = "camara-1873-redacao"

    override func setUp() async throws {
        continueAfterFailure = false
    }

    @MainActor private func launched(_ id: String, arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication.fiscal()
        app.launchArguments +=
            [
                "-FiscalDataScenario", "normal", "-FiscalFollowScenario", "normal",
                "-fiscal.developer.openURL", "fiscal://vote/\(id)",
            ] + arguments
        app.launch()
        let title = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "1873")
        ).firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 30))
        return app
    }

    @MainActor private func ballotsLink(in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Ver os")).firstMatch
    }

    @MainActor func testTheBarKeepsTheScoreAndJumpsToItsPart() {
        let app = launched(nominal)
        capture(app, "vote-top")
        let shortcut = app.buttons["Por partido"]
        for _ in 0..<4 where !shortcut.isHittable { app.swipeUp() }
        XCTAssertTrue(shortcut.isHittable)
        XCTAssertTrue(app.buttons["Quem votou"].exists)
        XCTAssertTrue(app.buttons["O que muda"].exists)
        capture(app, "vote-sticky-header")
        shortcut.tap()
        XCTAssertTrue(app.staticTexts["Por partido"].waitForExistence(timeout: 10))
        _ = XCTWaiter.wait(for: [XCTestExpectation(description: "jump settles")], timeout: 2)
        capture(app, "vote-sticky-parties")
    }

    @MainActor func testSeeingEveryVoteOpensTheListWithItsFilters() {
        let app = launched(nominal)
        let link = ballotsLink(in: app)
        for _ in 0..<12 where !link.isHittable { app.swipeUp() }
        XCTAssertTrue(link.isHittable)
        link.tap()
        let everyone = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Tudo")
        ).firstMatch
        XCTAssertTrue(everyone.waitForExistence(timeout: 15))
        capture(app, "vote-ballots")
    }

    @MainActor func testAVoiceVoteSaysWhatTheHouseRecorded() {
        let app = launched(voice)
        let text = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Votação simbólica")
        ).firstMatch
        XCTAssertTrue(text.waitForExistence(timeout: 15))
        XCTAssertFalse(ballotsLink(in: app).exists)
        capture(app, "vote-symbolic")
    }

    @MainActor func testTheEndIsReachableAtTheLargestTextSize() {
        let app = launched(
            nominal,
            arguments: [
                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
            ])
        capture(app, "vote-largest-top")
        let link = ballotsLink(in: app)
        for _ in 0..<60 where !link.isHittable { app.swipeUp() }
        XCTAssertTrue(link.isHittable)
        capture(app, "vote-largest-end")
    }

    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "\(name)-\(Int(app.windowWidth))pt"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
