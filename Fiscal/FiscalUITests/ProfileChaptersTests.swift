import XCTest

final class ProfileChaptersTests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    @MainActor private func launched(
        _ slug: String, arguments: [String] = []
    ) -> XCUIApplication {
        let app = XCUIApplication.fiscal()
        app.launchArguments +=
            [
                "-FiscalDataScenario", "normal", "-FiscalFollowScenario", "normal",
                "-fiscal.developer.openURL", "fiscal://person/\(slug)",
            ] + arguments
        app.launch()
        XCTAssertTrue(app.staticTexts["Ilustração do Fiscal"].waitForExistence(timeout: 30))
        return app
    }

    @MainActor func testShortcutsAppearOnScrollAndJumpToTheirChapter() {
        let app = launched("tabata-amaral")
        XCTAssertTrue(app.images["Ilustração de Tabata Amaral"].firstMatch.exists)
        capture(app, "profile-top")
        let shortcut = app.buttons["Quanto gasta"]
        for _ in 0..<4 where !shortcut.isHittable { app.swipeUp() }
        XCTAssertTrue(shortcut.isHittable)
        capture(app, "profile-sticky-header")
        shortcut.tap()
        XCTAssertTrue(app.staticTexts["Quanto gasta"].waitForExistence(timeout: 10))
        let every = app.buttons["Ver todas as notas"]
        XCTAssertTrue(every.waitForExistence(timeout: 10))
        _ = XCTWaiter.wait(for: [XCTestExpectation(description: "jump settles")], timeout: 2)
        for _ in 0..<8 where !every.isHittable { app.swipeUp(velocity: .slow) }
        XCTAssertTrue(every.isHittable)
        capture(app, "profile-money")
    }

    @MainActor func testAGovernorOnlySeesTheChaptersWithData() {
        let app = launched("tarcisio-de-freitas")
        capture(app, "governor-top")
        let origin = app.buttons["De onde vem"]
        for _ in 0..<4 where !origin.isHittable { app.swipeUp() }
        XCTAssertTrue(origin.isHittable)
        XCTAssertFalse(app.buttons["Como vota"].exists)
        XCTAssertFalse(app.buttons["Quanto gasta"].exists)
        XCTAssertFalse(app.buttons["Durante o mandato"].exists)
        XCTAssertFalse(app.staticTexts["Durante o mandato"].exists)
        capture(app, "governor-chapters")
    }

    @MainActor func testShareButtonsSayWhatTheyShareAndOpenTheCard() {
        let app = launched("tabata-amaral")
        let share = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Compartilhar o voto em")
        ).firstMatch
        XCTAssertTrue(app.scrollDown(until: share, attempts: 10))
        for _ in 0..<3 where !share.isHittable { app.swipeUp() }
        share.tap()
        XCTAssertTrue(app.staticTexts["Onde postar"].waitForExistence(timeout: 15))
        capture(app, "share-ballot")
    }

    @MainActor func testTheEndIsReachableAtTheLargestTextSize() {
        let app = launched(
            "tabata-amaral",
            arguments: [
                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
            ])
        capture(app, "profile-largest-top")
        let votes = app.staticTexts["Como vota"]
        for _ in 0..<30 where !votes.isHittable { app.swipeUp() }
        XCTAssertTrue(votes.isHittable)
        capture(app, "profile-largest-votes")
        let about = app.staticTexts["Quem é"]
        for _ in 0..<120 where !about.isHittable { app.swipeUp() }
        XCTAssertTrue(about.isHittable)
        app.swipeUp()
        capture(app, "profile-largest-end")
    }

    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "\(name)-\(Int(app.windowWidth))pt"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
