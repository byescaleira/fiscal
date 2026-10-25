import FeatureCore
import FiscalDesignSystem
import SwiftUI

struct AccentColorSection: View {
    @Environment(SettingsModel.self) private var settings
    @Environment(\.appTint) private var appTint

    var body: some View {
        @Bindable var settings = settings
        Section {
            RetroColorPicker(hex: $settings.tint)
        } header: {
            HStack(alignment: .firstTextBaseline) {
                Text("Accent Color").sectionTitle()
                Spacer()
                Text(settings.tintName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(appTint)
                    .lineLimit(1)
                    .contentTransition(.opacity)
            }
            .textCase(nil)
        } footer: {
            Text("The accent color appears on buttons, tabs, selections and charts.")
        }
    }
}
