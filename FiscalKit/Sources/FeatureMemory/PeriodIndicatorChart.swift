import Charts
import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct PeriodIndicatorChart: View {
    @ReducesMotion private var reduceMotion
    @ScaledMetric(relativeTo: .caption) private var height: CGFloat = .chartCompactHeight
    @State private var revealed = false
    @State private var scrubbed: Int?
    let indicator: PeriodIndicator
    let color: Color
    let logScale: Bool

    private var selected: HistoryPoint? {
        guard let scrubbed else { return nil }
        return indicator.points.min { abs($0.year - scrubbed) < abs($1.year - scrubbed) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceS) {
            if let selected {
                ChartCallout(title: selected.yearText, value: indicator.valueText(selected.value)) {
                    EmptyView()
                }
            }
            chart
                .frame(height: height)
                .chartXSelection(value: $scrubbed)
                .sensoryFeedback(.selection, trigger: selected)
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .chartReveal(0)) { revealed = true }
        }
    }

    @ViewBuilder private var chart: some View {
        if logScale {
            Chart(indicator.points) { point in
                LineMark(x: .value("Year", point.year), y: .value("Value", point.value))
                    .foregroundStyle(color)
                    .interpolationMethod(.monotone)
                PointMark(x: .value("Year", point.year), y: .value("Value", point.value))
                    .foregroundStyle(point == selected ? Color.primary : color)
                    .symbolSize(point == selected ? .chartPointFocusSize : .chartPointSize)
                    .accessibilityLabel(point.yearText)
                    .accessibilityValue(indicator.valueText(point.value))
            }
            .chartYScale(type: .log)
            .chartXAxis { yearAxis }
            .opacity(revealed ? 1 : 0)
        } else {
            Chart {
                ForEach(indicator.points) { point in
                    BarMark(
                        x: .value("Year", point.year),
                        y: .value("Value", revealed ? point.value : 0),
                        width: .ratio(.chartBarWidth)
                    )
                    .foregroundStyle(point == selected ? Color.primary : color)
                    .accessibilityLabel(point.yearText)
                    .accessibilityValue(indicator.valueText(point.value))
                }
                RuleMark(y: .value("Zero", 0))
                    .foregroundStyle(.secondary)
                    .lineStyle(StrokeStyle(lineWidth: .chartRuleWidth))
                    .accessibilityHidden(true)
                if let average = indicator.average {
                    RuleMark(y: .value("Average", average))
                        .foregroundStyle(.secondary)
                        .lineStyle(.chartAverage)
                        .accessibilityHidden(true)
                }
            }
            .chartXAxis { yearAxis }
        }
    }

    private var yearAxis: some AxisContent {
        AxisMarks(values: .automatic(desiredCount: 5)) { value in
            AxisValueLabel {
                if let year = value.as(Int.self) {
                    Text(verbatim: HistoryPoint.yearText(year))
                }
            }
        }
    }
}
