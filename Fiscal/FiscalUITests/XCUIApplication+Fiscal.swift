import XCTest

@MainActor
extension XCUIApplication {
    static func fiscal() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(pt-BR)", "-AppleLocale", "pt_BR", "-FiscalLiveScenario", "close",
        ]
        return app
    }

    var windowWidth: CGFloat {
        windows.firstMatch.frame.width
    }

    func waitForSections() -> Bool {
        buttons["Ajustes"].firstMatch.waitForExistence(timeout: 30)
    }

    #if !os(tvOS)
        func openSettings() -> Bool {
            buttons["Ajustes"].firstMatch.tap()
            return navigationBars["Ajustes"].waitForExistence(timeout: 10)
        }
    #endif
}
