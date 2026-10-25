import Charts
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct MonthlyBarsChart: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .caption) private var height: CGFloat = .chartHeight
    @State private var revealed = false
    @State private var scrubbed: String?
    let months: [MonthBar]
    let highlighted: Int?
    let averageReais: Double?
    @Binding var selection: Int?

    private var scrubbedMonth: MonthBar? { months.first { $0.label == scrubbed } }

    var body: some View {
        Chart {
            ForEach(months) { month in
                BarMark(
                    x: .value("Month", month.label),
                    y: .value("Amount", revealed ? month.reais : 0),
                    width: .ratio(.chartBarWidth)
                )
                .foregroundStyle(style(for: month))
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: .space2XS, topTrailingRadius: .space2XS)
                )
                .accessibilityLabel(month.name)
                .accessibilityValue(month.value)
            }
            if let averageReais {
                RuleMark(y: .value("Average", averageReais))
                    .foregroundStyle(.secondary)
                    .lineStyle(.chartAverage)
                    .annotation(position: .top, alignment: .leading, spacing: .space2XS) {
                        if scrubbedMonth == nil {
                            Text("Average")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityHidden(true)
            }
            if let scrubbedMonth {
                RuleMark(x: .value("Selected", scrubbedMonth.label))
                    .foregroundStyle(Color.secondary.opacity(.opacitySoft))
                    .lineStyle(StrokeStyle(lineWidth: .chartRuleWidth))
                    .zIndex(-1)
                    .annotation(
                        position: .top, spacing: .space2XS,
                        overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                    ) {
                        MonthCallout(month: scrubbedMonth, averageReais: averageReais)
                    }
                    .accessibilityHidden(true)
            }
        }
        .chartXScale(domain: months.map(\.label))
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
        .onChange(of: scrubbed) { _, label in
            guard let label else { return }
            selection = months.first { $0.label == label }?.month
        }
        .sensoryFeedback(.selection, trigger: selection)
        .frame(height: height)
        .onAppear {
            withAnimation(reduceMotion ? nil : .smooth(duration: 1)) { revealed = true }
        }
    }

    private func style(for month: MonthBar) -> AnyShapeStyle {
        if month.month == highlighted { return AnyShapeStyle(Color.info.gradient) }
        return AnyShapeStyle(Color.primary.opacity(.opacitySoft))
    }
}

private struct MonthCallout: View {
    let month: MonthBar
    let averageReais: Double?

    var body: some View {
        ChartCallout(title: month.name, value: month.value) {
            if let averageReais, averageReais > 0, month.cents != nil {
                let change = month.reais / averageReais - 1
                Label {
                    Text(
                        verbatim: String(
                            appLocalized: "\(PublicFormat.percent(abs(change))) vs. average")
                    )
                    .monospacedDigit()
                } icon: {
                    Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            }
        }
    }
}
