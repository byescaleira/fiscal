import FeatureCore
import FiscalDesignSystem
import SwiftUI

struct AccentColorSection: View {
    @Environment(SettingsModel.self) private var settings
    @Environment(\.appTint) private var appTint

    var body: some View {
        Section {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: .accentSwatch), spacing: .spaceM)],
                spacing: .spaceL
            ) {
                ForEach(RetroColor.allCases) { AccentSwatch(color: $0) }
            }
            .padding(.vertical, .spaceS)
            .sensoryFeedback(.selection, trigger: settings.tint)
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
            Text(
                "The accent color appears on buttons, tabs and theme chips. Votes, charts and parties keep their own colors."
            )
        }
    }
}

private struct AccentSwatch: View {
    @Environment(SettingsModel.self) private var settings
    let color: RetroColor

    var body: some View {
        let isSelected = RetroColor(hex: settings.tint) == color
        Button {
            settings.tint = color.hex
        } label: {
            VStack(spacing: .spaceXS) {
                RoundedRectangle(cornerRadius: .radiusM, style: .continuous)
                    .fill(color.color.gradient)
                    .frame(height: .badgeXL)
                    .overlay {
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.icon(.m, weight: .bold))
                                .foregroundStyle(.white)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.space2XS)
                    .overlay {
                        RoundedRectangle(cornerRadius: .radiusM + .space2XS, style: .continuous)
                            .strokeBorder(
                                isSelected ? color.color : .clear, lineWidth: .selectionStroke)
                    }
                Text(verbatim: color.name)
                    .font(.caption.weight(isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .contentShape(.rect)
            .animation(.snappy, value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: color.name))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
