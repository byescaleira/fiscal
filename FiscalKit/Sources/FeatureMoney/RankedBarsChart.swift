import Charts
import FiscalDesignSystem
import SwiftUI

extension MoneyTone {
    var color: Color {
        switch self {
        case .teal: .retroTeal
        case .denim: .retroDenim
        case .plum: .retroPlum
        case .brown: .retroBrown
        case .orange: .retroOrange
        }
    }
}

extension AmountBar {
    var color: Color { ChartPalette.color(at: slot) }
}

struct RankedBarsChart: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .caption) private var rowHeight: CGFloat = .badgeL
    @State private var revealed = false
    @State private var scrubbed: String?
    let bars: [AmountBar]
    @Binding var selection: String?

    var body: some View {
        Chart(bars) { bar in
            BarMark(
                xStart: .value("Start", 0),
                xEnd: .value("Amount", revealed ? bar.reais : 0),
                y: .value("Item", bar.id),
                height: .fixed(.barHeight)
            )
            .foregroundStyle(style(for: bar))
            .clipShape(.capsule)
            .annotation(
                position: .top, alignment: .leading, spacing: .space2XS,
                overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
            ) {
                RankedBarLabel(bar: bar, isSelected: bar.title == selection)
            }
            .accessibilityLabel(bar.title)
            .accessibilityValue(accessibilityValue(for: bar))
        }
        .chartXScale(
            domain: 0...max(bars.map(\.reais).max() ?? 1, 1),
            range: .plotDimension(endPadding: 0)
        )
        .chartYScale(domain: bars.map(\.id))
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYSelection(value: $scrubbed)
        .onChange(of: scrubbed) { _, id in
            guard let id, let bar = bars.first(where: { $0.id == id }) else { return }
            selection = selection == bar.title ? nil : bar.title
        }
        .sensoryFeedback(.selection, trigger: selection)
        .frame(height: rowHeight * CGFloat(max(bars.count, 1)))
        .onAppear {
            withAnimation(reduceMotion ? nil : .smooth(duration: 1)) { revealed = true }
        }
    }

    private func style(for bar: AmountBar) -> AnyShapeStyle {
        guard let selection, selection != bar.title else {
            return AnyShapeStyle(bar.color.gradient)
        }
        return AnyShapeStyle(bar.color.opacity(.opacitySoft))
    }

    private func accessibilityValue(for bar: AmountBar) -> String {
        [bar.value, bar.percent, bar.detail].compactMap(\.self).joined(separator: ", ")
    }
}

private struct RankedBarLabel: View {
    let bar: AmountBar
    let isSelected: Bool

    var body: some View {
        HStack(spacing: .space2XS) {
            Image(systemName: bar.kind.symbol)
                .foregroundStyle(bar.color)
                .accessibilityHidden(true)
            Text(verbatim: bar.title)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(.primary)
                .lineLimit(1)
            Text(verbatim: "·").foregroundStyle(.tertiary)
            Text(verbatim: bar.value)
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundStyle(.primary)
            Text(verbatim: bar.percent)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            if let detail = bar.detail {
                Text(verbatim: detail).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .font(.caption)
    }
}
