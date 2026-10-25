import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct LensThemesStep: View {
    @Environment(LensSetupModel.self) private var setup
    @Environment(\.appTint) private var tint

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceXL) {
            LensStepHeader(
                "What matters most to you?",
                message: setup.suggestionText.map { Text(verbatim: $0) }
                    ?? Text("Choose 3 to 5 topics. Fiscal puts them first."))
            HStack(spacing: .spaceS) {
                Chip(setup.themeCountText, color: tint, shape: .capsule)
                    .contentTransition(.numericText())
                Spacer()
            }
            ThemeGrid()
            ThemeMoreButton()
        }
    }
}

struct ThemeGrid: View {
    @Environment(LensSetupModel.self) private var setup

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: .choiceTile), spacing: .spaceM)],
            spacing: .spaceM
        ) {
            ForEach(setup.themeChoices) { theme in
                ThemeTile(theme: theme)
            }
        }
    }
}

private struct ThemeTile: View {
    @Environment(LensSetupModel.self) private var setup
    @Environment(\.appTint) private var tint
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let theme: Theme

    var body: some View {
        let isSelected = setup.isChosen(theme)
        Button {
            setup.toggle(theme)
        } label: {
            VStack(spacing: .spaceS) {
                Image(systemName: theme.symbol)
                    .font(.icon(.l, weight: .semibold))
                    .foregroundStyle(isSelected ? tint : .primary)
                    .symbolEffect(.bounce, value: reduceMotion ? false : isSelected)
                    .frame(height: .badgeL)
                Text(verbatim: theme.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            .padding(.spaceM)
            .frame(maxWidth: .infinity, minHeight: .choiceTile)
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(tint)
                        .padding(.spaceS)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .contentShape(.rect(cornerRadius: .radiusL))
        }
        .buttonStyle(.plain)
        .lensChoice(isSelected: isSelected)
        .opacity(setup.canToggle(theme) ? 1 : .opacitySoft)
        .disabled(!setup.canToggle(theme))
        .accessibilityLabel(Text(verbatim: theme.title))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct ThemeMoreButton: View {
    @Environment(LensSetupModel.self) private var setup

    var body: some View {
        Button {
            setup.showsMoreThemes.toggle()
        } label: {
            Group {
                if setup.showsMoreThemes {
                    Label("Fewer topics", systemImage: "chevron.up")
                } else {
                    Label("More topics", systemImage: "chevron.down")
                }
            }
            .font(.subheadline.weight(.semibold))
        }
        .buttonStyle(.borderless)
        .frame(maxWidth: .infinity)
    }
}
