import Charts
import FiscalDesignSystem
import SwiftUI

struct SalaryLollipopChart: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .caption) private var rowHeight: CGFloat = .badgeL
    @ScaledMetric(relativeTo: .caption) private var labelRoom: CGFloat = .chartLabelRoom
    @State private var revealed = false
    @State private var scrubbed: String?
    let salaries: [MoneyModel.Salary]

    private var ordered: [MoneyModel.Salary] { salaries.sorted { $0.cents > $1.cents } }

    var body: some View {
        Chart(ordered) { salary in
            RuleMark(
                xStart: .value("Start", 0),
                xEnd: .value("Pay", revealed ? salary.reais : 0),
                y: .value("Office", salary.title)
            )
            .lineStyle(StrokeStyle(lineWidth: .chartStemWidth, lineCap: .round))
            .foregroundStyle(
                Color.companion.opacity(isDimmed(salary) ? .opacityTint : .opacitySoft)
            )
            .accessibilityHidden(true)
            PointMark(
                x: .value("Pay", revealed ? salary.reais : 0),
                y: .value("Office", salary.title)
            )
            .symbolSize(salary.title == scrubbed ? .chartPointFocusSize : .chartPointSize)
            .foregroundStyle(Color.companion.opacity(isDimmed(salary) ? .opacitySoft : 1))
            .annotation(position: .trailing, spacing: .spaceS) {
                Text(verbatim: salary.value)
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(isDimmed(salary) ? .secondary : .primary)
            }
            .accessibilityLabel(salary.title)
            .accessibilityValue(salary.value)
        }
        .chartXScale(
            domain: 0...max(ordered.first?.reais ?? 1, 1),
            range: .plotDimension(endPadding: labelRoom)
        )
        .chartYScale(domain: ordered.map(\.title))
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisValueLabel()
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .chartYSelection(value: $scrubbed)
        .sensoryFeedback(.selection, trigger: scrubbed)
        .animation(reduceMotion ? nil : .smooth, value: scrubbed)
        .frame(height: rowHeight * CGFloat(max(ordered.count, 1)))
        .onAppear {
            withAnimation(reduceMotion ? nil : .smooth(duration: 1)) { revealed = true }
        }
    }

    private func isDimmed(_ salary: MoneyModel.Salary) -> Bool {
        guard let scrubbed else { return false }
        return scrubbed != salary.title
    }
}
