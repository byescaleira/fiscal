import FeatureCore
import FiscalDesignSystem

extension Guide {
    static var tourPages: [TutorialPage] {
        [
            TutorialPage(
                animation: .launch, title: "Welcome to Fiscal",
                message:
                    "Everything starts on the Today tab. Settings, in its toolbar, keeps the choices that are yours."
            ),
            TutorialPage(
                animation: .done, title: "Five Tabs",
                message: "Each tab keeps its own place, so you can switch without losing your way.",
                steps: [
                    GuideStep(
                        "newspaper", color: .retroOrange, title: "Today",
                        detail: "The day's votes, sessions and live count."),
                    GuideStep(
                        "person.2", color: .retroTeal, title: "Mine",
                        detail: "Who represents you and who you follow."),
                    GuideStep(
                        "checkmark.square", color: .retroDenim, title: "Votes",
                        detail: "Floor votes and who voted how."),
                    GuideStep(
                        "brazilianrealsign", color: .retroOlive, title: "Money",
                        detail: "Where public money goes."),
                    GuideStep(
                        "magnifyingglass", color: .retroPlum, title: "Search",
                        detail: "Find anyone, compare and follow elections."),
                ]),
        ]
    }

    static var appearancePages: [TutorialPage] {
        [
            TutorialPage(
                animation: .editor, title: "Make It Yours",
                message:
                    "In Settings › Appearance, pick the theme and the accent color."
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
