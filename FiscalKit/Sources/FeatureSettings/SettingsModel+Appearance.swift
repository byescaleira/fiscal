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
            title: String(appLocalized: "Live Results"),
            caption: String(appLocalized: "Polling stations counted"),
            headline: 0.87.formatted(.percent.locale(.app)),
            rows: [
                ThemeSample.Row(
                    symbol: "checkmark.square", title: String(appLocalized: "Counted"),
                    color: .mustard, detail: 0.87.formatted(.percent.locale(.app)), fraction: 0.87),
                ThemeSample.Row(
                    symbol: "person.2", title: String(appLocalized: "Turnout"), color: .teal,
                    detail: 0.79.formatted(.percent.locale(.app)), fraction: 0.79),
            ])
    }
}
