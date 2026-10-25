import XCTest

@MainActor
extension XCUIApplication {
    static func fiscal() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-FiscalLiveScenario", "close",
        ]
        return app
    }

    var windowWidth: CGFloat {
        windows.firstMatch.frame.width
    }

    func waitForSections() -> Bool {
        buttons["Settings"].firstMatch.waitForExistence(timeout: 30)
    }

    #if !os(tvOS)
        func openSettings() -> Bool {
            buttons["Settings"].firstMatch.tap()
            return navigationBars["Settings"].waitForExistence(timeout: 10)
        }
    #endif
}
