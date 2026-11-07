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
        buttons["Feed"].firstMatch.waitForExistence(timeout: 30)
    }

    func scrollDown(until element: XCUIElement, attempts: Int = 12) -> Bool {
        for _ in 0..<attempts {
            if element.exists { return true }
            swipeUp()
        }
        return element.exists
    }

    func showFeed() {
        buttons["Feed"].firstMatch.tap()
    }

    #if !os(tvOS)
        func openSettings() -> Bool {
            showFeed()
            guard buttons["Ajustes"].firstMatch.waitForExistence(timeout: 10) else { return false }
            buttons["Ajustes"].firstMatch.tap()
            return staticTexts["Privacidade"].waitForExistence(timeout: 10)
        }
    #endif
}
