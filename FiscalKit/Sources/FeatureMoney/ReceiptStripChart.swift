import Charts
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct ReceiptStripChart: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .caption) private var height: CGFloat = .chartCompactHeight
    @State private var revealed = false
    @State private var scrubbed: Double?
    let receipts: [ReceiptPoint]
    let medianReais: Double?
    let category: String?

    private var domain: ClosedRange<Double> {
        let values = receipts.map(\.reais)
        let lower = values.min() ?? 1
        let upper = max(values.max() ?? lower, lower * 10)
        return lower...upper
    }

    private var selected: ReceiptPoint? {
        guard let scrubbed, scrubbed > 0 else { return nil }
        let target = log10(scrubbed)
        return receipts.min { abs(log10($0.reais) - target) < abs(log10($1.reais) - target) }
    }

    private var ticks: [Double] {
        let range = domain
        let first = Int(log10(range.lowerBound).rounded(.up))
        let last = Int(log10(range.upperBound).rounded(.down))
        guard first <= last else { return [] }
        return (first...last).map { pow(10, Double($0)) }
    }

    var body: some View {
        Chart {
            ForEach(receipts) { receipt in
                PointMark(
                    x: .value("Amount", receipt.reais),
                    y: .value("Lane", revealed ? Double(receipt.lane) : 0)
                )
                .symbolSize(receipt == selected ? .chartPointFocusSize : .chartDotSize)
                .foregroundStyle(style(for: receipt))
                .accessibilityLabel(receipt.supplier)
                .accessibilityValue("\(receipt.value), \(receipt.category)")
            }
            if let medianReais, medianReais > 0 {
                RuleMark(x: .value("Median", medianReais))
                    .foregroundStyle(.primary)
                    .lineStyle(.chartAverage)
                    .annotation(position: .top, spacing: .space2XS) {
                        if selected == nil {
                            Text("Median")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityHidden(true)
            }
            if let selected {
                RuleMark(x: .value("Selected", selected.reais))
                    .foregroundStyle(Color.secondary.opacity(.opacitySoft))
                    .lineStyle(StrokeStyle(lineWidth: .chartRuleWidth))
                    .zIndex(-1)
                    .annotation(
                        position: .top, spacing: .space2XS,
                        overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                    ) {
                        ChartCallout(title: selected.supplier, value: selected.value) {}
                    }
                    .accessibilityHidden(true)
            }
        }
        .chartXScale(domain: domain, type: .log)
        .chartYScale(domain: -1...Double(Int.chartJitterLanes))
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: ticks) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let reais = value.as(Double.self) {
                        Text(verbatim: PublicFormat.compactMoney(cents: Int(reais * 100)))
                    }
                }
            }
        }
        .chartXSelection(value: $scrubbed)
        .sensoryFeedback(.selection, trigger: selected?.id)
        .frame(height: height)
        .onAppear {
            withAnimation(reduceMotion ? nil : .smooth(duration: 1)) { revealed = true }
        }
    }

    private func style(for receipt: ReceiptPoint) -> AnyShapeStyle {
        if receipt == selected { return AnyShapeStyle(Color.info) }
        if let category, receipt.category != category {
            return AnyShapeStyle(Color.secondary.opacity(.opacityTint))
        }
        return AnyShapeStyle(Color.info.opacity(category == nil ? .opacitySoft : .opacityStrong))
    }
}
