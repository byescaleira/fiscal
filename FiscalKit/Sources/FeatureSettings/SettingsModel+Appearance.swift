import FeatureCore
import FiscalDomain
import Foundation

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
}
