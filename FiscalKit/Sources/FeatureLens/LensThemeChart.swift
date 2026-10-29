import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct LensThemeBars: View {
    @Environment(LensModel.self) private var lens
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.liteMode) private var liteMode
    let tally: LensThemeTally

    var body: some View {
        let reduceMotion = systemReduceMotion || liteMode.reducesMotion
        VStack(alignment: .leading, spacing: .spaceM) {
            VStack(alignment: .leading, spacing: .spaceXS) {
                Chip("RECENT VOTES · \(tally.total)", color: .secondary)
                Text(verbatim: tally.headline)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            ForEach(tally.slices) { slice in
                Button {
                    lens.focus(slice.theme)
                } label: {
                    LensThemeBarRow(
                        slice: slice, share: tally.share(of: slice),
                        isFocused: lens.focusedTheme == slice.theme,
                        isDimmed: lens.focusedTheme.map { $0 != slice.theme } ?? false
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(slice.theme.title)
                .accessibilityValue(lens.accessibilityValue(for: slice))
                .accessibilityHint(Text("Shows the recent votes on this topic"))
                .accessibilityAddTraits(lens.focusedTheme == slice.theme ? .isSelected : [])
            }
        }
        .padding(.vertical, .spaceS)
        .sensoryFeedback(.selection, trigger: lens.focusedTheme)
        .animation(reduceMotion ? nil : .smooth, value: lens.focusedTheme)
    }
}

private struct LensThemeBarRow: View {
    let slice: LensThemeTally.Slice
    let share: Double
    let isFocused: Bool
    let isDimmed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceXS) {
            LensThemeBarLabel(slice: slice, isFocused: isFocused)
            ShareBarChart(
                value: share, color: ChartPalette.color(at: slice.slot), height: .barHeight)
        }
        .opacity(isDimmed ? .opacitySoft : 1)
        .contentShape(.rect)
    }
}

private struct LensThemeBarLabel: View {
    @Environment(LensModel.self) private var lens
    let slice: LensThemeTally.Slice
    let isFocused: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: .space2XS) {
            Image(systemName: slice.theme.symbol)
                .foregroundStyle(ChartPalette.color(at: slice.slot))
                .accessibilityHidden(true)
            Text(verbatim: slice.theme.title)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Text(verbatim: "·").foregroundStyle(.tertiary)
            Text(verbatim: PublicFormat.number(slice.count))
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundStyle(.primary)
            if let approved = lens.approvedText(for: slice) {
                Text(verbatim: approved)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: .zero)
            Image(systemName: isFocused ? "chevron.down" : "chevron.forward")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
                .contentTransition(.symbolEffect(.replace))
                .accessibilityHidden(true)
        }
        .font(.subheadline)
    }
}

struct LensFocusedVoteRow: View {
    let vote: VoteSummary

    var body: some View {
        RouteLink(.vote(id: vote.id)) {
            VStack(alignment: .leading, spacing: .space2XS) {
                Text(verbatim: "\(vote.house.title) · \(vote.heading)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(verbatim: vote.plainSummary ?? vote.summary)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                if let approved = vote.approved {
                    let title: LocalizedStringKey = approved ? "Approved" : "Rejected"
                    Label(title, systemImage: approved ? "checkmark.seal" : "xmark.seal")
                        .font(.chipLabel)
                        .foregroundStyle(approved ? Color.positive : Color.negative)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct LensThemeOrderRow: View {
    @Environment(LensModel.self) private var lens
    let theme: Theme
    let index: Int

    var body: some View {
        HStack(spacing: .spaceM) {
            Text(verbatim: lens.rankText(index))
                .font(.emphasis(.headline, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(minWidth: .badgeS)
            SymbolBadge(theme.symbol, color: ChartPalette.color(at: index), style: .filled)
            VStack(alignment: .leading, spacing: .space2XS) {
                Text(verbatim: theme.title).font(.rowTitle)
                Text(verbatim: theme.coverage)
                    .font(.rowDetail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: .zero)
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: theme.title))
        .accessibilityValue(Text(verbatim: lens.rankText(index)))
        .accessibilityAction(named: Text("Move Up")) {
            Task { await lens.moveTheme(theme, by: -1) }
        }
        .accessibilityAction(named: Text("Move Down")) {
            Task { await lens.moveTheme(theme, by: 1) }
        }
        .accessibilityAction(named: Text("Remove")) {
            Task { await lens.removeTheme(theme) }
        }
        .contextMenu {
            Button("Move Up", systemImage: "arrow.up") {
                Task { await lens.moveTheme(theme, by: -1) }
            }
            .disabled(index == 0)
            Button("Move Down", systemImage: "arrow.down") {
                Task { await lens.moveTheme(theme, by: 1) }
            }
            .disabled(index == lens.themes.count - 1)
            Button("Remove", systemImage: "minus.circle", role: .destructive) {
                Task { await lens.removeTheme(theme) }
            }
            .disabled(lens.lens?.canRemoveTheme != true)
        }
    }
}
