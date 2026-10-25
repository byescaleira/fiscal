import Charts
import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct ThemeBarsChart: View {
    @Environment(SearchModel.self) private var search
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false
    @State private var opened: Theme?
    let activity: ThemeActivity

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceM) {
            ForEach(Array(activity.slices.enumerated()), id: \.element.id) { index, slice in
                Button {
                    opened = slice.theme
                    search.apply(.theme(slice.theme))
                } label: {
                    ThemeBarRow(slice: slice, maxCount: activity.maxCount, revealed: revealed)
                        .animation(reduceMotion ? nil : .chartReveal(index), value: revealed)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(slice.theme.title)
                .accessibilityValue(search.accessibilityValue(for: slice))
                .accessibilityHint(Text("Shows the recent votes on this topic"))
            }
        }
        .sensoryFeedback(.selection, trigger: opened)
        .onAppear { revealed = true }
    }
}

private struct ThemeBarRow: View {
    let slice: ThemeActivity.Slice
    let maxCount: Int
    let revealed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceXS) {
            ThemeBarLabel(slice: slice)
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
            .accessibilityHidden(true)
        }
        .contentShape(.rect)
    }
}

private struct ThemeBarLabel: View {
    @Environment(SearchModel.self) private var search
    let slice: ThemeActivity.Slice

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
            if let approved = search.approvedText(for: slice) {
                Text(verbatim: approved)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Image(systemName: "chevron.forward")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .font(.subheadline)
    }
}

struct ThemeCadenceChart: View {
    @Environment(SearchModel.self) private var search
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .caption) private var height: CGFloat = .chartCompactHeight
    @State private var revealed = false
    @State private var scrubbed: Date?
    let activity: ThemeActivity

    private var selected: ThemeActivity.Period? { scrubbed.flatMap(activity.period(at:)) }

    var body: some View {
        Chart {
            ForEach(activity.periods) { period in
                BarMark(
                    x: .value("Date", period.start, unit: activity.grain.unit),
                    y: .value("Votes", revealed ? period.count : 0),
                    width: .ratio(.chartBarWidth)
                )
                .foregroundStyle(style(for: period))
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: .space2XS, topTrailingRadius: .space2XS)
                )
                .accessibilityLabel(search.title(for: period, in: activity))
                .accessibilityValue(search.countText(period.count))
            }
            if let average = activity.average {
                RuleMark(y: .value("Average", average))
                    .foregroundStyle(.secondary)
                    .lineStyle(.chartAverage)
                    .accessibilityHidden(true)
            }
            if let selected {
                RuleMark(x: .value("Selected", selected.start, unit: activity.grain.unit))
                    .foregroundStyle(Color.secondary.opacity(.opacitySoft))
                    .lineStyle(StrokeStyle(lineWidth: .chartRuleWidth))
                    .zIndex(-1)
                    .annotation(
                        position: .top, spacing: .space2XS,
                        overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                    ) {
                        CadenceCallout(period: selected, activity: activity)
                    }
                    .accessibilityHidden(true)
            }
        }
        .chartXSelection(value: $scrubbed)
        .chartScrollableAxes(activity.isScrollable ? .horizontal : [])
        .chartXVisibleDomain(length: activity.visibleLength)
        .chartScrollPosition(initialX: activity.scrollStart ?? .now)
        .sensoryFeedback(.selection, trigger: selected?.start)
        .chartXAxis {
            AxisMarks(values: .stride(by: activity.grain.unit)) { value in
                if let date = value.as(Date.self), activity.showsLabel(at: date) {
                    AxisValueLabel(format: axisFormat)
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .frame(height: height)
        .onAppear {
            withAnimation(reduceMotion ? nil : .smooth(duration: 1)) { revealed = true }
        }
    }

    private var axisFormat: Date.FormatStyle {
        dynamicTypeSize.isAccessibilitySize ? .dateTime.day() : .dateTime.day().month(.abbreviated)
    }

    private func style(for period: ThemeActivity.Period) -> AnyShapeStyle {
        guard let selected, period != selected else { return AnyShapeStyle(Color.info.gradient) }
        return AnyShapeStyle(Color.info.opacity(.opacitySoft))
    }
}

private struct CadenceCallout: View {
    @Environment(SearchModel.self) private var search
    let period: ThemeActivity.Period
    let activity: ThemeActivity

    var body: some View {
        ChartCallout(
            title: search.title(for: period, in: activity), value: search.countText(period.count)
        ) {
            if !period.themes.isEmpty {
                HStack(spacing: .space2XS) {
                    ForEach(period.themes, id: \.self) { theme in
                        Image(systemName: theme.symbol)
                            .foregroundStyle(ChartPalette.color(at: activity.slot(of: theme)))
                    }
                }
                .font(.caption)
                .accessibilityHidden(true)
            }
        }
    }
}
