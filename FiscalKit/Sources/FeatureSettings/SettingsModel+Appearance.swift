import FeatureCore
import FiscalDomain
import Foundation

struct ThemeSample {
    struct Row: Identifiable {
        let symbol: String
        let title: String
        let color: RetroColor
        let detail: String
        let fraction: Double

        var id: String { symbol }
    }

    let title: String
    let caption: String
    let headline: String
    let rows: [Row]
}

extension SettingsModel {
    var tintName: String { RetroColor.name(for: tint) }

    var themeFooter: String {
        switch appearance {
        case .system:
            String(appLocalized: "Fiscal follows the light and dark setting of your device.")
        case .light, .dark:
            String(appLocalized: "Fiscal keeps this look whatever your device uses.")
        }
    }

    var themeSample: ThemeSample {
        ThemeSample(
            title: String(appLocalized: "Home"),
            caption: String(appLocalized: "Your Items"),
            headline: 12.formatted(.number.locale(.app)),
            rows: [
                ThemeSample.Row(
                    symbol: "lightbulb", title: String(appLocalized: "First idea"), color: .mustard,
                    detail: String(appLocalized: "Today"), fraction: 0.64),
                ThemeSample.Row(
                    symbol: "calendar", title: String(appLocalized: "Weekend plan"), color: .teal,
                    detail: String(appLocalized: "Yesterday"), fraction: 0.3),
            ])
    }

    var languageFooter: String {
        String(
            appLocalized:
                "Fiscal changes language right away. System texts, such as the keyboard and date pickers, follow the next time the app opens."
        )
    }
}
