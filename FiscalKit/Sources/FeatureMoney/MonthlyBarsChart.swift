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

    var body: some View {
        Chart {
            ForEach(months) { month in
                BarMark(
                    x: .value("Month", month.label),
                    y: .value("Amount", revealed ? month.reais : 0),
                    width: .ratio(.chartBarWidth)
                )
                .foregroundStyle(
                    month.month == highlighted
                        ? AnyShapeStyle(Color.info.gradient)
                        : AnyShapeStyle(Color.primary.opacity(.opacitySoft))
                )
                .clipShape(.rect(cornerRadius: .space2XS))
                .accessibilityLabel(month.name)
                .accessibilityValue(month.value)
            }
            if let averageReais {
                RuleMark(y: .value("Average", averageReais))
                    .foregroundStyle(.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [.space2XS, .space2XS]))
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
}
