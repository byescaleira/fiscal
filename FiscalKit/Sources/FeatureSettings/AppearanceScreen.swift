import FeatureCore
import FiscalDesignSystem
import SwiftUI

struct AppearanceScreen: View {
    var body: some View {
        SettingsPage("Appearance") {
            AppearancePreviewSection()
            ThemeSection()
            AccentColorSection()
            AppIconSection()
        }
    }
}
