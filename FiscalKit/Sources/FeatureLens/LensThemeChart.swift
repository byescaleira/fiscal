import Charts
import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct LensThemeBars: View {
    @Environment(LensModel.self) private var lens
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false
    let tally: LensThemeTally

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceM) {
            VStack(alignment: .leading, spacing: .spaceXS) {
                Chip("RECENT VOTES · \(tally.total)", color: .secondary)
                Text(verbatim: tally.headline)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            ForEach(Array(tally.slices.enumerated()), id: \.element.id) { index, slice in
                Button {
                    lens.focus(slice.theme)
                } label: {
                    LensThemeBarRow(
                        slice: slice, maxCount: tally.maxCount, revealed: revealed,
                        isFocused: lens.focusedTheme == slice.theme,
                        isDimmed: lens.focusedTheme.map { $0 != slice.theme } ?? false
                    )
                    .animation(reduceMotion ? nil : .chartReveal(index), value: revealed)
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
        .animation(.smooth, value: lens.focusedTheme)
        .onAppear { revealed = true }
    }
}

private struct LensThemeBarRow: View {
    let slice: LensThemeTally.Slice
    let maxCount: Int
    let revealed: Bool
    let isFocused: Bool
    let isDimmed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceXS) {
            LensThemeBarLabel(slice: slice, isFocused: isFocused)
            Chart {
                BarMark(
                    xStart: .value("Start", 0),
                    xEnd: .value("Votes", revealed ? slice.count : 0),
                    y: .value("Topic", slice.id),
                    height: .fixed(.barHeight)
                )
                .foregroundStyle(ChartPalette.color(at: slice.slot).gradient)
                .clipShape(.capsule)
            }
            .chartXScale(domain: 0...max(maxCount, 1), range: .plotDimension(endPadding: 0))
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
            .frame(height: .barHeight)
            .background(Color.secondary.opacity(.opacityFill), in: .capsule)
            .accessibilityHidden(true)
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
                Text(verbatim: "\(vote.house.title) · \(vote.proposition)")
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
                .font(.headline.width(.condensed))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(minWidth: .badgeS)
            LensThemeChip(theme: theme)
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
        .contextMenu {
            Button("Move Up", systemImage: "arrow.up") {
                Task { await lens.moveTheme(theme, by: -1) }
            }
            .disabled(index == 0)
            Button("Move Down", systemImage: "arrow.down") {
                Task { await lens.moveTheme(theme, by: 1) }
            }
            .disabled(index == lens.themes.count - 1)
        }
    }
}

struct LensThemeChip: View {
    @Environment(\.appTint) private var tint
    let theme: Theme

    var body: some View {
        Label(theme.title, systemImage: theme.symbol)
            .font(.chipLabel)
            .foregroundStyle(tint)
            .padding(.horizontal, .spaceM)
            .padding(.vertical, .spaceS)
            .background(tint.opacity(.opacityTint), in: .capsule)
    }
}
