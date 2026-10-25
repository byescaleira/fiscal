import FiscalDesignSystem
import SwiftUI

struct ThemeSection: View {
    @Environment(SettingsModel.self) private var settings

    var body: some View {
        Section {
            HStack(alignment: .top, spacing: .spaceM) {
                ForEach(Appearance.allCases) { ThemeChoice(appearance: $0) }
            }
            .padding(.vertical, .spaceS)
            .sensoryFeedback(.selection, trigger: settings.appearance)
        } header: {
            Text("Theme").sectionTitle()
        } footer: {
            Text(settings.themeFooter)
        }
    }
}

private struct ThemeChoice: View {
    @Environment(SettingsModel.self) private var settings
    @Environment(\.appTint) private var appTint
    let appearance: Appearance

    var body: some View {
        let isSelected = settings.appearance == appearance
        Button {
            settings.appearance = appearance
        } label: {
            VStack(spacing: .spaceS) {
                ThemePreview(appearance: appearance)
                    .padding(.space2XS)
                    .overlay {
                        RoundedRectangle(cornerRadius: .radiusM + .space2XS, style: .continuous)
                            .stroke(isSelected ? appTint : .clear, lineWidth: 3)
                    }
                Text(appearance.title)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                SelectionMark(isSelected: isSelected)
            }
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(appearance.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
