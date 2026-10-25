import FeatureCore
import FiscalDesignSystem
import SwiftUI

struct AppIconSection: View {
    @Environment(SettingsModel.self) private var settings

    var body: some View {
        if settings.supportsAlternateIcons {
            Section {
                ForEach(AppIcon.allCases) { icon in
                    Button {
                        Task { await settings.setAppIcon(icon) }
                    } label: {
                        HStack(spacing: .spaceM) {
                            AppIconImage(icon: icon, size: .badgeXL)
                            Text(icon.title).font(.rowTitle).foregroundStyle(.primary)
                            Spacer()
                            SelectionMark(isSelected: settings.appIcon == icon)
                        }
                    }
                    .accessibilityAddTraits(settings.appIcon == icon ? .isSelected : [])
                }
            } header: {
                Text("App Icon").sectionTitle()
            } footer: {
                Text("Pick the icon you like best on your Home Screen.")
            }
        }
    }
}
