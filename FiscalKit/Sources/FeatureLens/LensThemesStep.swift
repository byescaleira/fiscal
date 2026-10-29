import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct LensThemesStep: View {
    @Environment(LensSetupModel.self) private var setup
    @Environment(\.appTint) private var tint
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.liteMode) private var liteMode

    var body: some View {
        let reduceMotion = systemReduceMotion || liteMode.reducesMotion
        VStack(alignment: .leading, spacing: .spaceXL) {
            LensStepHeader("Your topics", message: Text(verbatim: setup.themesMessage))
            HStack(spacing: .spaceS) {
                Chip(setup.themeCountText, color: tint, shape: .capsule)
                    .contentTransition(.numericText())
                if setup.isLoadingActivity {
                    ProgressView().controlSize(.small)
                    Text("Reading what they did")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: .zero)
            }
            VStack(spacing: .spaceM) {
                ForEach(Array(setup.draft.themes.enumerated()), id: \.element) { index, theme in
                    LensThemeCard(theme: theme, index: index)
                        .transition(
                            reduceMotion ? .opacity : .scale(scale: 0.96).combined(with: .opacity))
                }
            }
            .animation(reduceMotion ? nil : .smooth, value: setup.draft.themes)
            LensMoreThemes()
        }
    }
}

private struct LensThemeCard: View {
    @Environment(LensSetupModel.self) private var setup
    let theme: Theme
    let index: Int

    var body: some View {
        let color = ChartPalette.color(at: index)
        HStack(alignment: .top, spacing: .spaceM) {
            Text(verbatim: setup.rankText(index))
                .font(.scoreboardTitle)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(minWidth: .badgeS)
            SymbolBadge(theme.symbol, color: color, size: .badgeL, style: .filled)
            VStack(alignment: .leading, spacing: .spaceXS) {
                Text(verbatim: theme.title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Text(verbatim: theme.coverage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let entry = setup.entry(for: theme) {
                    ShareBarChart(value: setup.share(of: entry), color: color, height: .barHeight)
                    Text(verbatim: setup.actionsText(for: entry))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: .zero)
            LensThemeControls(theme: theme)
        }
        .padding(.spaceL)
        .surface(in: .rect(cornerRadius: .radiusL))
        .contentShape(.rect(cornerRadius: .radiusL))
        .draggable(theme.rawValue)
        .dropDestination(for: String.self) { items, _ in
            guard let moved = items.first.flatMap(Theme.init(rawValue:)) else { return false }
            setup.move(moved, before: theme)
            return true
        }
        .accessibilityElement(children: .combine)
        .accessibilityActions {
            if !setup.isFirst(theme) {
                Button("Move Up") { setup.move(theme, by: -1) }
            }
            if !setup.isLast(theme) {
                Button("Move Down") { setup.move(theme, by: 1) }
            }
            if setup.draft.canRemoveTheme {
                Button("Remove") { setup.remove(theme) }
            }
        }
    }
}

private struct LensThemeControls: View {
    @Environment(LensSetupModel.self) private var setup
    let theme: Theme

    var body: some View {
        VStack(spacing: .spaceS) {
            Button("Move Up", systemImage: "chevron.up") { setup.move(theme, by: -1) }
                .disabled(setup.isFirst(theme))
            Button("Move Down", systemImage: "chevron.down") { setup.move(theme, by: 1) }
                .disabled(setup.isLast(theme))
            Button("Remove", systemImage: "minus") { setup.remove(theme) }
                .disabled(!setup.draft.canRemoveTheme)
        }
        .lensRoundButton()
        .accessibilityHidden(true)
    }
}

private struct LensMoreThemes: View {
    @Environment(LensSetupModel.self) private var setup

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceM) {
            VStack(alignment: .leading, spacing: .space2XS) {
                Text("Add a topic").sectionTitle().accessibilityAddTraits(.isHeader)
                Text(
                    setup.draft.canAddTheme
                        ? LocalizedStringKey("Nothing is hidden: the others stay one tap away.")
                        : "Remove a topic to add another. Up to 5."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            VStack(spacing: .zero) {
                let others = setup.otherThemes
                ForEach(others) { theme in
                    LensAddThemeRow(theme: theme)
                    if theme != others.last {
                        Divider().padding(.leading, .badgeM + .spaceL + .spaceM)
                    }
                }
            }
            .surface(in: .rect(cornerRadius: .radiusL))
        }
    }
}

private struct LensAddThemeRow: View {
    @Environment(LensSetupModel.self) private var setup
    @Environment(\.appTint) private var tint
    let theme: Theme

    var body: some View {
        Button {
            setup.add(theme)
        } label: {
            HStack(spacing: .spaceM) {
                SymbolBadge(theme.symbol, color: tint, size: .badgeM)
                VStack(alignment: .leading, spacing: .space2XS) {
                    Text(verbatim: theme.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(
                        verbatim: setup.entry(for: theme).map(setup.actionsText(for:))
                            ?? theme.coverage
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                }
                Spacer(minLength: .spaceS)
                Image(systemName: "plus.circle.fill")
                    .font(.icon(.m))
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, .spaceL)
            .padding(.vertical, .spaceM)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!setup.draft.canAddTheme)
        .opacity(setup.draft.canAddTheme ? 1 : .opacitySoft)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Adds this topic to your lens"))
    }
}
