import Charts
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct OriginColumnsChart: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .caption) private var height: CGFloat = .chartHeight
    @State private var revealed = false
    @State private var scrubbed: String?
    let bars: [AmountBar]

    private var selected: AmountBar? { bars.first { $0.id == scrubbed } }

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceM) {
            chart
            VStack(alignment: .leading, spacing: .spaceXS) {
                ForEach(bars) { OriginLegendRow(bar: $0) }
            }
        }
    }

    private var chart: some View {
        Chart {
            ForEach(bars) { bar in
                BarMark(
                    x: .value("Origin", bar.id),
                    y: .value("Amount", revealed ? bar.reais : 0),
                    width: .ratio(.chartBarWidth)
                )
                .foregroundStyle(style(for: bar))
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: .spaceXS, topTrailingRadius: .spaceXS)
                )
                .annotation(position: .top, spacing: .space2XS) {
                    if selected == nil {
                        Text(verbatim: bar.percent)
                            .font(.caption2.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityLabel(bar.title)
                .accessibilityValue("\(bar.value), \(bar.percent)")
            }
            if let selected {
                RuleMark(x: .value("Selected", selected.id))
                    .foregroundStyle(Color.secondary.opacity(.opacitySoft))
                    .lineStyle(StrokeStyle(lineWidth: .chartRuleWidth))
                    .zIndex(-1)
                    .annotation(
                        position: .top, spacing: .space2XS,
                        overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                    ) {
                        ChartCallout(title: selected.title, value: selected.value) {
                            Text(verbatim: selected.percent)
                                .font(.caption.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityHidden(true)
            }
        }
        .chartXScale(domain: bars.map(\.id))
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let id = value.as(String.self), let bar = bars.first(where: { $0.id == id })
                    {
                        Image(systemName: bar.kind.symbol)
                            .font(.subheadline)
                            .foregroundStyle(bar.color)
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
        .sensoryFeedback(.selection, trigger: scrubbed)
        .frame(height: height)
        .onAppear {
            withAnimation(reduceMotion ? nil : .smooth(duration: 1)) { revealed = true }
        }
    }

    private func style(for bar: AmountBar) -> AnyShapeStyle {
        guard let selected, selected != bar else { return AnyShapeStyle(bar.color.gradient) }
        return AnyShapeStyle(bar.color.opacity(.opacitySoft))
    }
}

private struct OriginLegendRow: View {
    let bar: AmountBar

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: .spaceS) {
            Image(systemName: bar.kind.symbol)
                .foregroundStyle(bar.color)
                .frame(minWidth: .badgeS)
                .accessibilityHidden(true)
            Text(verbatim: bar.title)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: .spaceS)
            Text(verbatim: bar.value)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .font(.footnote)
        .accessibilityElement(children: .combine)
    }
}
