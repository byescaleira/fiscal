import XCTest

final class FollowingTests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    @MainActor private func launched(
        link: String, follow: String? = "normal", place: String = "sp", arguments: [String] = []
    ) -> XCUIApplication {
        let app = XCUIApplication.fiscal()
        app.launchArguments +=
            [
                "-FiscalDataScenario", "normal", "-fiscal.mine.place", place,
                "-fiscal.developer.openURL", link,
            ] + (follow.map { ["-FiscalFollowScenario", $0] } ?? []) + arguments
        app.launch()
        XCTAssertTrue(app.waitForSections())
        return app
    }

    @MainActor private func followingRow(in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Quem você segue")
        ).firstMatch
    }

    @MainActor private func starting(_ text: String, in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", text)).firstMatch
    }

    @MainActor func testRegionStartsOnThePlace() {
        let app = launched(link: "fiscal://region")
        XCTAssertTrue(app.staticTexts["Sua região"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["Quem você segue"].exists)
        XCTAssertFalse(app.staticTexts["Sugestões"].exists)
        capture(app, "region-top")
    }

    @MainActor func testTheFollowingFilterOpensWhoYouFollow() {
        let app = launched(link: "fiscal://feed")
        let filter = app.buttons["Seguindo"]
        XCTAssertTrue(app.scrollDown(until: filter))
        for _ in 0..<3 where !filter.isHittable { app.swipeUp(velocity: .slow) }
        filter.tap()
        let row = followingRow(in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        XCTAssertTrue(row.label.contains("5"))
        capture(app, "feed-following")
        row.tap()
        let person = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Tabata Amaral")
        ).firstMatch
        XCTAssertTrue(person.waitForExistence(timeout: 15))
        capture(app, "following")
        XCTAssertTrue(app.scrollDown(until: app.staticTexts["Sugestões"], attempts: 8))
    }

    @MainActor func testTheLinkOpensTheScreenAndWithoutAPlaceInvitesToChooseIt() {
        let app = launched(link: "fiscal://following", follow: "empty", place: "")
        XCTAssertTrue(starting("Você ainda não segue", in: app).waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["Sugestões"].exists)
        capture(app, "following-empty")
        let invite = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Escolha seu lugar")
        ).firstMatch
        XCTAssertTrue(invite.exists)
        invite.tap()
        XCTAssertTrue(app.staticTexts["Sua região"].waitForExistence(timeout: 15))
    }

    @MainActor func testTheFeedInviteLeadsToTheScreen() {
        let app = launched(link: "fiscal://feed", follow: "empty")
        let invite = app.buttons["Ver quem representa você"]
        XCTAssertTrue(app.scrollDown(until: invite, attempts: 20))
        for _ in 0..<3 where !invite.isHittable { app.swipeUp(velocity: .slow) }
        invite.tap()
        XCTAssertTrue(starting("Você ainda não segue", in: app).waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Siga quem representa você"].waitForExistence(timeout: 15))
    }

    @MainActor func testFollowingAndUnfollowingWorkOnTheScreen() {
        let app = launched(link: "fiscal://following", follow: nil)
        let follow = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Seguir ")
        ).firstMatch
        XCTAssertTrue(app.scrollDown(until: follow, attempts: 15))
        for _ in 0..<3 where !follow.isHittable { app.swipeUp(velocity: .slow) }
        let name = String(follow.label.dropFirst("Seguir ".count))
        follow.tap()
        let unfollow = app.buttons["Deixar de seguir \(name)"].firstMatch
        XCTAssertTrue(unfollow.waitForExistence(timeout: 10))
        for _ in 0..<12 where !unfollow.isHittable { app.swipeDown() }
        XCTAssertTrue(unfollow.isHittable)
        unfollow.tap()
        XCTAssertTrue(app.buttons["Seguir \(name)"].firstMatch.waitForExistence(timeout: 10))
    }

    @MainActor func testTheEndIsReachableAtTheLargestTextSize() {
        let app = launched(
            link: "fiscal://following",
            arguments: [
                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
            ])
        let suggestions = app.staticTexts["Sugestões"]
        XCTAssertTrue(app.scrollDown(until: suggestions, attempts: 40))
        capture(app, "following-largest")
    }

    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "\(name)-\(Int(app.windowWidth))pt"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
