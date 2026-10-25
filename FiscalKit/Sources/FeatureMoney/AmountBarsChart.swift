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

struct AmountBarsChart: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .caption) private var rowHeight: CGFloat = .badgeL
    @State private var revealed = false
    let bars: [AmountBar]

    var body: some View {
        Chart(bars) { bar in
            BarMark(
                xStart: .value("Start", 0),
                xEnd: .value("Amount", revealed ? bar.reais : 0),
                y: .value("Item", bar.id),
                height: .fixed(.barHeight)
            )
            .foregroundStyle(bar.kind.tone.color.gradient)
            .clipShape(.capsule)
            .annotation(
                position: .top, alignment: .leading, spacing: .space2XS,
                overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
            ) {
                AmountBarLabel(bar: bar)
            }
            .accessibilityLabel(bar.title)
            .accessibilityValue(bar.value)
        }
        .chartXScale(domain: 0...max(bars.map(\.reais).max() ?? 1, 1))
        .chartYScale(domain: bars.map(\.id))
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: rowHeight * CGFloat(max(bars.count, 1)))
        .onAppear {
            withAnimation(reduceMotion ? nil : .smooth(duration: 1)) { revealed = true }
        }
    }
}

private struct AmountBarLabel: View {
    let bar: AmountBar

    var body: some View {
        HStack(spacing: .space2XS) {
            Image(systemName: bar.kind.symbol)
                .foregroundStyle(bar.kind.tone.color)
                .accessibilityHidden(true)
            Text(verbatim: bar.title)
                .foregroundStyle(.primary)
                .lineLimit(1)
            Text(verbatim: "·").foregroundStyle(.tertiary)
            Text(verbatim: bar.value)
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundStyle(.primary)
            if let detail = bar.detail {
                Text(verbatim: detail).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .font(.caption)
    }
}
