import Charts
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

public struct IndicatorCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .caption) private var height: CGFloat = .chartCompactHeight
    @State private var revealed = false
    @State private var scrubbed: Date?
    private let indicator: Indicator
    private let area: Indicator.Area?
    private let calendar: Calendar

    public init(
        indicator: Indicator, scope: String = Indicator.brazil,
        calendar: Calendar = FiscalCalendar.current
    ) {
        self.indicator = indicator
        area = indicator.area(closestTo: scope)
        self.calendar = calendar
    }

    private var series: [IndicatorPoint] { area?.series ?? [] }

    private var latest: IndicatorPoint? { series.last }

    private var yearChange: Double? {
        guard let latest,
            let before = IndicatorMath.value(
                in: series, at: IndicatorMath.month(latest.date, adding: -12))
        else { return nil }
        return IndicatorMath.change(from: before, to: latest.value)
    }

    private var selected: IndicatorPoint? {
        guard let scrubbed else { return nil }
        let day = CalendarDay(scrubbed, calendar: calendar)
        return series.min {
            abs(IndicatorMath.months(from: $0.date, to: day))
                < abs(IndicatorMath.months(from: $1.date, to: day))
        }
    }

    private var domain: ClosedRange<Double> {
        let values = series.map(\.value)
        guard let low = values.min(), let high = values.max(), high > low else { return 0...1 }
        let pad = (high - low) * 0.08
        return (low - pad)...(high + pad)
    }

    private var summary: String {
        let value = IndicatorFormat.value(latest?.value, kind: indicator.kind)
        let month = IndicatorFormat.month(latest?.date, calendar: calendar)
        let place = area?.name ?? ""
        return String(
            appLocalized:
                "\(indicator.name), \(place): \(value) in \(month), \(IndicatorFormat.change(yearChange)) in 12 months"
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: .spaceS) {
            HStack(alignment: .firstTextBaseline, spacing: .spaceS) {
                Label(indicator.name, systemImage: IndicatorFormat.symbol(id: indicator.id))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer(minLength: .spaceS)
                if let area {
                    Text(verbatim: area.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: .spaceS) {
                Text(verbatim: IndicatorFormat.value(latest?.value, kind: indicator.kind))
                    .font(.scoreboardNumber)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .amountLine()
                Text(verbatim: IndicatorFormat.month(latest?.date, calendar: calendar))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if yearChange != nil {
                Chip(
                    String(appLocalized: "12 months · \(IndicatorFormat.change(yearChange))"),
                    color: .info)
            }
            chart
            Text(verbatim: IndicatorFormat.unitLine(unit: indicator.unit, kind: indicator.kind))
                .font(.caption2)
                .foregroundStyle(.tertiary)
            if let source = SourceFootnote.text(indicator.sources, calendar: calendar) {
                Text(verbatim: source).font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding(.spaceM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.groupedRow, in: .rect(cornerRadius: .radiusM))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: summary))
    }

    private var chart: some View {
        Chart {
            ForEach(series, id: \.date) { point in
                AreaMark(
                    x: .value("Month", point.date.date(in: calendar), unit: .month),
                    yStart: .value("Base", domain.lowerBound),
                    yEnd: .value("Value", revealed ? point.value : domain.lowerBound)
                )
                .foregroundStyle(ChartPalette.color(at: 0).opacity(.opacityTint).gradient)
                .interpolationMethod(.monotone)
                LineMark(
                    x: .value("Month", point.date.date(in: calendar), unit: .month),
                    y: .value("Value", revealed ? point.value : domain.lowerBound)
                )
                .foregroundStyle(ChartPalette.color(at: 0))
                .interpolationMethod(.monotone)
            }
            if let selected {
                RuleMark(x: .value("Selected", selected.date.date(in: calendar), unit: .month))
                    .foregroundStyle(Color.secondary.opacity(.opacitySoft))
                    .lineStyle(StrokeStyle(lineWidth: .chartRuleWidth))
                    .annotation(
                        position: .top, spacing: .space2XS,
                        overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                    ) {
                        ChartCallout(
                            title: IndicatorFormat.month(selected.date, calendar: calendar),
                            value: IndicatorFormat.value(selected.value, kind: indicator.kind)
                        ) {
                            EmptyView()
                        }
                    }
            }
        }
        .chartYScale(domain: domain)
        .chartXSelection(value: $scrubbed)
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel(format: .dateTime.year())
            }
        }
        .sensoryFeedback(.selection, trigger: selected?.date)
        .frame(height: height)
        .accessibilityHidden(true)
        .onAppear {
            withAnimation(reduceMotion ? nil : .smooth(duration: 1)) { revealed = true }
        }
    }
}
