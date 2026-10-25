import Charts
import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct ThemeBarsChart: View {
    @Environment(SearchModel.self) private var search
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .subheadline) private var rowHeight: CGFloat = .chartRowHeight
    @State private var revealed = false
    @State private var opened: Theme?
    let activity: ThemeActivity

    var body: some View {
        Chart(activity.slices) { slice in
            BarMark(
                xStart: .value("Start", 0),
                xEnd: .value("Votes", revealed ? slice.count : 0),
                y: .value("Topic", slice.id),
                height: .fixed(.barHeight)
            )
            .foregroundStyle(ChartPalette.color(at: slice.slot).gradient)
            .clipShape(.capsule)
            .offset(y: barOffset)
            .annotation(
                position: .top, alignment: .leading, spacing: .space2XS,
                overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
            ) {
                ThemeBarLabel(slice: slice, lines: labelLines)
            }
            .accessibilityLabel(slice.theme.title)
            .accessibilityValue(search.accessibilityValue(for: slice))
        }
        .chartXScale(domain: 0...max(activity.maxCount, 1), range: .plotDimension(endPadding: 0))
        .chartYScale(domain: activity.slices.map(\.id))
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartGesture { proxy in
            SpatialTapGesture()
                .onEnded { value in
                    guard let id: String = proxy.value(atY: value.location.y),
                        let theme = Theme(rawValue: id)
                    else { return }
                    open(theme)
                }
        }
        .sensoryFeedback(.selection, trigger: opened)
        .accessibilityActions {
            ForEach(activity.slices) { slice in
                Button(String(appLocalized: "Show votes about \(slice.theme.title)")) {
                    open(slice.theme)
                }
            }
        }
        .frame(height: rowHeight * CGFloat(labelLines) * CGFloat(max(activity.slices.count, 1)))
        .onAppear {
            withAnimation(reduceMotion ? nil : .smooth(duration: 1)) { revealed = true }
        }
    }

    private var labelLines: Int { dynamicTypeSize.isAccessibilitySize ? 2 : 1 }

    private var barOffset: CGFloat {
        max((rowHeight * CGFloat(labelLines) - .barHeight) / 2 - .spaceXS, 0)
    }

    private func open(_ theme: Theme) {
        opened = theme
        search.apply(.theme(theme))
    }
}

private struct ThemeBarLabel: View {
    @Environment(SearchModel.self) private var search
    let slice: ThemeActivity.Slice
    let lines: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: .space2XS) {
            Image(systemName: slice.theme.symbol)
                .foregroundStyle(ChartPalette.color(at: slice.slot))
                .accessibilityHidden(true)
            Text(verbatim: slice.theme.title)
                .foregroundStyle(.primary)
                .lineLimit(lines)
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
        .sensoryFeedback(.selection, trigger: selected?.start)
        .chartXAxis {
            AxisMarks(values: .stride(by: activity.grain.unit)) { value in
                if let date = value.as(Date.self), activity.showsLabel(at: date) {
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
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
