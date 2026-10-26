import Charts
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct YearTrendChart: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .caption) private var height: CGFloat = .chartCompactHeight
    @State private var revealed = false
    @State private var scrubbed: Int?
    let points: [YearPoint]

    private var selected: YearPoint? {
        guard let scrubbed else { return nil }
        return points.min { abs($0.year - scrubbed) < abs($1.year - scrubbed) }
    }

    private var domain: ClosedRange<Int> {
        (points.first?.year ?? 0)...(points.last?.year ?? 0)
    }

    var body: some View {
        Chart {
            ForEach(points) { point in
                AreaMark(
                    x: .value("Year", point.year),
                    y: .value("Amount", revealed ? point.reais : 0)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.info.opacity(.opacityTint), Color.info.opacity(.opacityHidden),
                        ],
                        startPoint: .top, endPoint: .bottom)
                )
                .accessibilityHidden(true)
                LineMark(
                    x: .value("Year", point.year),
                    y: .value("Amount", revealed ? point.reais : 0)
                )
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: .chartLineWidth, lineCap: .round))
                .foregroundStyle(Color.info)
                .accessibilityHidden(true)
                PointMark(
                    x: .value("Year", point.year),
                    y: .value("Amount", revealed ? point.reais : 0)
                )
                .symbolSize(
                    point.isCurrent || point == selected ? .chartPointFocusSize : .chartPointSize
                )
                .foregroundStyle(point.isCurrent ? Color.info : Color.info.opacity(.opacityStrong))
                .accessibilityLabel(String(point.year))
                .accessibilityValue(point.fullValue)
            }
            if let selected {
                RuleMark(x: .value("Selected", selected.year))
                    .foregroundStyle(Color.secondary.opacity(.opacitySoft))
                    .lineStyle(StrokeStyle(lineWidth: .chartRuleWidth))
                    .zIndex(-1)
                    .annotation(
                        position: .top, spacing: .space2XS,
                        overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                    ) {
                        ChartCallout(title: String(selected.year), value: selected.fullValue) {}
                    }
                    .accessibilityHidden(true)
            }
        }
        .chartXScale(domain: domain, range: .plotDimension(padding: .spaceL))
        .chartXAxis {
            AxisMarks(values: points.map(\.year)) { value in
                AxisValueLabel {
                    if let year = value.as(Int.self) {
                        Text(verbatim: String(year))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let reais = value.as(Double.self) {
                        Text(verbatim: PublicFormat.compactMoney(cents: Int(reais * 100)))
                    }
                }
            }
        }
        .chartXSelection(value: $scrubbed)
        .sensoryFeedback(.selection, trigger: selected?.year)
        .frame(height: height)
        .onAppear {
            withAnimation(reduceMotion ? nil : .smooth(duration: 1)) { revealed = true }
        }
    }
}
