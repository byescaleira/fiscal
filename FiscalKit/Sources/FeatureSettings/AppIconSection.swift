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
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: .iconTile), spacing: .spaceM)],
                        alignment: .center, spacing: .spaceL
                    ) {
                        ForEach(collection.icons) { AppIconTile(icon: $0) }
                    }
                    .padding(.vertical, .spaceS)
                } header: {
                    Text(collection == .main ? String(appLocalized: "App Icon") : collection.title)
                        .sectionTitle()
                } footer: {
                    AppIconFooter(collection: collection)
                }
            }
            .sensoryFeedback(.selection, trigger: settings.appIcon)
        }
    }
}

private struct AppIconFooter: View {
    let collection: AppIcon.Collection

    var body: some View {
        switch collection {
        case .main: Text("The Amazon at dawn is the main icon. Pick the one you like best.")
        case .themes: Text("One icon for each Lens palette.")
        case .fauna: EmptyView()
        case .parties:
            Text(
                "Only each party's own colors, with no logo or number, for every party registered with the TSE, in alphabetical order."
            )
        }
    }
}

private struct AppIconTile: View {
    @Environment(SettingsModel.self) private var settings
    @Environment(\.appTint) private var tint
    let icon: AppIcon

    var body: some View {
        let isSelected = settings.appIcon == icon
        Button {
            Task { await settings.setAppIcon(icon) }
        } label: {
            VStack(spacing: .spaceS) {
                AppIconImage(icon: icon, size: .iconTileImage)
                    .padding(.space2XS)
                    .overlay {
                        RoundedRectangle(cornerRadius: .iconTileRadius, style: .continuous)
                            .strokeBorder(isSelected ? tint : .clear, lineWidth: .selectionStroke)
                    }
                    .overlay(alignment: .topTrailing) {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.icon(.m))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, tint)
                                .offset(x: .spaceXS, y: -.spaceXS)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                Text(verbatim: icon.title)
                    .font(.caption.weight(isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
            .animation(.snappy, value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: icon.title))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
