import FeatureCore
import FiscalDesignSystem
import SwiftUI

struct AppIconSection: View {
    @Environment(SettingsModel.self) private var settings
    @Environment(\.featureFlags) private var flags

    var body: some View {
        if settings.supportsAlternateIcons {
            ForEach(AppIcon.Collection.visible(partyIcons: flags?.isOn(.partyIcons) == true)) {
                collection in
                Section {
                    ForEach(collection.icons) { icon in
                        AppIconRow(icon: icon)
                    }
                } header: {
                    Text(collection == .main ? String(appLocalized: "App Icon") : collection.title)
                        .sectionTitle()
                } footer: {
                    switch collection {
                    case .main: Text("Pick the icon you like best on your Home Screen.")
                    case .parties:
                        Text(
                            "Only each party's own colors, with no logo or number, for every party registered with the TSE, in alphabetical order."
                        )
                    default: EmptyView()
                    }
                }
            }
        }
    }
}

private struct AppIconRow: View {
    @Environment(SettingsModel.self) private var settings
    let icon: AppIcon

    var body: some View {
        Button {
            Task { await settings.setAppIcon(icon) }
        } label: {
            HStack(spacing: .spaceM) {
                AppIconImage(icon: icon, size: .badgeXL)
                Text(icon.title).font(.rowTitle).foregroundStyle(Color.primary)
                Spacer()
                SelectionMark(isSelected: settings.appIcon == icon)
            }
        }
        .accessibilityAddTraits(settings.appIcon == icon ? .isSelected : [])
    }
}
