import Charts
import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct MandateStackChart: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .caption) private var rowHeight: CGFloat = .badgeL
    @ScaledMetric(relativeTo: .caption) private var labelRoom: CGFloat = .chartLabelRoom
    @State private var revealed = false
    @State private var scrubbed: String?
    let segments: [MandateSegment]
    let totals: [MandateRoleTotal]
    let kinds: [MandateCost.Kind]

    private var peak: Double {
        Double(totals.map(\.monthlyCents).max() ?? 100) / 100
    }

    private var focused: MandateRoleTotal? {
        totals.first { $0.title == scrubbed }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceS) {
            if let focused {
                ChartCallout(title: focused.title, value: focused.monthly) { EmptyView() }
            }
            chart
        }
        .animation(reduceMotion ? nil : .smooth, value: scrubbed)
        .onAppear {
            withAnimation(reduceMotion ? nil : .smooth(duration: 1)) { revealed = true }
        }
    }

    private var chart: some View {
        Chart(segments) { segment in
            BarMark(
                x: .value("Amount", revealed ? segment.reais : 0),
                y: .value("Office", segment.roleTitle),
                height: .fixed(.barHeight * 2)
            )
            .foregroundStyle(by: .value("Item", segment.kindTitle))
            .opacity(isDimmed(segment) ? .opacitySoft : 1)
            .annotation(position: .trailing, spacing: .spaceS) {
                if segment.isLast, let total = totals.first(where: { $0.role == segment.role }) {
                    Text(verbatim: total.compactMonthly)
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(isDimmed(segment) ? .secondary : .primary)
                }
            }
            .accessibilityLabel("\(segment.roleTitle), \(segment.kindTitle)")
            .accessibilityValue(segment.value)
        }
        .chartForegroundStyleScale(
            domain: kinds.map(MandateText.kindTitle),
            range: kinds.map { kind in
                ChartPalette.color(at: MandateCost.Kind.allCases.firstIndex(of: kind) ?? 0)
            }
        )
        .chartXScale(domain: 0...max(peak, 1), range: .plotDimension(endPadding: labelRoom))
        .chartYScale(domain: totals.map(\.title))
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisValueLabel()
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .chartLegend(position: .bottom, alignment: .leading, spacing: .spaceM)
        .chartYSelection(value: $scrubbed)
        .sensoryFeedback(.selection, trigger: scrubbed)
        .frame(height: rowHeight * CGFloat(max(totals.count, 1)) + rowHeight)
    }

    private func isDimmed(_ segment: MandateSegment) -> Bool {
        guard let scrubbed else { return false }
        return scrubbed != segment.roleTitle
    }
}

struct QuotaStatesChart: View {
    @Environment(MoneyModel.self) private var money
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .caption) private var height: CGFloat = .chartHeight
    @State private var revealed = false
    @State private var scrubbed: String?
    let bars: [QuotaStateBar]

    private var color: Color {
        ChartPalette.color(at: MandateCost.Kind.allCases.firstIndex(of: .quota) ?? 1)
    }

    private var focused: QuotaStateBar? {
        bars.first { $0.code == scrubbed } ?? money.selectedQuotaBar
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceS) {
            if let focused {
                ChartCallout(title: focused.title, value: focused.value) { EmptyView() }
            }
            chart
        }
        .animation(reduceMotion ? nil : .smooth, value: focused)
        .onAppear {
            withAnimation(reduceMotion ? nil : .smooth(duration: 1)) { revealed = true }
        }
    }

    private var chart: some View {
        Chart(bars) { bar in
            BarMark(
                x: .value("State", bar.code),
                y: .value("Allowance", revealed ? bar.reais : 0),
                width: .ratio(.chartBarWidth)
            )
            .foregroundStyle(
                focused == nil || bar == focused
                    ? AnyShapeStyle(color.gradient) : AnyShapeStyle(color.opacity(.opacitySoft))
            )
            .clipShape(
                UnevenRoundedRectangle(topLeadingRadius: .space2XS, topTrailingRadius: .space2XS)
            )
            .accessibilityLabel(bar.title)
            .accessibilityValue(bar.value)
        }
        .chartXScale(domain: bars.map(\.code))
        .chartXAxis {
            AxisMarks { _ in
                if !dynamicTypeSize.isAccessibilitySize {
                    AxisValueLabel(centered: true)
                        .font(.caption2)
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
    }
}
