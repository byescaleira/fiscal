import FeatureCore
import FiscalDesignSystem
import SwiftUI

struct AppearanceScreen: View {
    var body: some View {
        SettingsPage("Appearance") {
            ThemeSection()
            AccentColorSection()
            AppIconSection()
        }
    }
}
