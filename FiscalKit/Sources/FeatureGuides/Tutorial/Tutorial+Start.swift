import FeatureCore
import FiscalDesignSystem

extension Guide {
    static var tourPages: [TutorialPage] {
        [
            TutorialPage(
                animation: .launch, title: "Welcome to Fiscal",
                message:
                    "Everything starts on the Home tab. Settings keeps the choices that are yours."
            ),
            TutorialPage(
                animation: .done, title: "Two Tabs",
                message: "Each tab keeps its own place, so you can switch without losing your way.",
                steps: [
                    GuideStep(
                        "house", color: .retroOrange, title: "Home",
                        detail: "What matters right now, at a glance."),
                    GuideStep(
                        "gearshape", color: .retroDenim, title: "Settings",
                        detail: "Appearance, language, guides and more."),
                ]),
        ]
    }

    static var appearancePages: [TutorialPage] {
        [
            TutorialPage(
                animation: .editor, title: "Make It Yours",
                message:
                    "In Settings › Appearance, pick the theme and the accent color. The language is in Settings › Language."
            )
        ]
    }

    static var privacyPages: [TutorialPage] {
        [
            TutorialPage(
                animation: .privacy, title: "Your Data Stays Yours",
                message:
                    "Everything lives on your device and in your iCloud. No account, no servers, no third parties."
            ),
            TutorialPage(
                animation: .backup, title: "Sync with iCloud",
                message: "Every device signed in to your Apple Account shows the same data."),
        ]
    }
}
