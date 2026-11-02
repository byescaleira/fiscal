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
        buttons["Seguindo"].firstMatch.waitForExistence(timeout: 30)
    }

    func scrollDown(until element: XCUIElement, attempts: Int = 12) -> Bool {
        for _ in 0..<attempts {
            if element.exists { return true }
            swipeUp()
        }
        return element.exists
    }

    func showToday() {
        buttons["Hoje"].firstMatch.tap()
    }

    #if !os(tvOS)
        func openSettings() -> Bool {
            showToday()
            guard buttons["Ajustes"].firstMatch.waitForExistence(timeout: 10) else { return false }
            buttons["Ajustes"].firstMatch.tap()
            return navigationBars["Ajustes"].waitForExistence(timeout: 10)
        }
    #endif
}
