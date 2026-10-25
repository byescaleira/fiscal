import Charts
import FiscalDesignSystem
import SwiftUI

struct CompositionChart: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var stripHeight: CGFloat = .chartStripHeight
    @State private var revealed = false
    @State private var scrubbed: Double?
    @State private var picked: String?
    let segments: [AmountBar]

    private var focused: AmountBar? {
        segments.first { $0.id == picked } ?? segments.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceM) {
            if let focused {
                ChartCallout(title: focused.title, value: focused.value) {
                    Text(verbatim: focused.percent)
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .contentTransition(reduceMotion ? .identity : .numericText())
            }
            Chart(segments) { segment in
                BarMark(
                    x: .value("Share", revealed ? segment.share : 0),
                    y: .value("Total", "total")
                )
                .foregroundStyle(style(for: segment))
                .accessibilityLabel(segment.title)
                .accessibilityValue("\(segment.value), \(segment.percent)")
            }
            .chartXScale(domain: 0...1)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
            .chartXSelection(value: $scrubbed)
            .onChange(of: scrubbed) { _, share in
                guard let share else { return }
                picked = segment(at: share)?.id
            }
            .sensoryFeedback(.selection, trigger: picked)
            .frame(height: stripHeight)
            .clipShape(.capsule)
            VStack(alignment: .leading, spacing: .spaceS) {
                ForEach(segments) { segment in
                    Button {
                        withAnimation(reduceMotion ? nil : .smooth) { picked = segment.id }
                    } label: {
                        CompositionLegendRow(segment: segment, isFocused: segment == focused)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(segment == focused ? .isSelected : [])
                }
            }
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .smooth(duration: 1)) { revealed = true }
        }
    }

    private func segment(at share: Double) -> AmountBar? {
        var start = 0.0
        for segment in segments {
            start += segment.share
            if share < start { return segment }
        }
        return segments.last
    }

    private func style(for segment: AmountBar) -> AnyShapeStyle {
        guard picked != nil, segment != focused else { return AnyShapeStyle(segment.color) }
        return AnyShapeStyle(segment.color.opacity(.opacitySoft))
    }
}

private struct CompositionLegendRow: View {
    let segment: AmountBar
    let isFocused: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: .spaceS) {
            RoundedRectangle(cornerRadius: .spaceHairline)
                .fill(segment.color)
                .frame(width: .chartLegendSwatch, height: .chartLegendSwatch)
                .accessibilityHidden(true)
            Image(systemName: segment.kind.symbol)
                .foregroundStyle(segment.color)
                .accessibilityHidden(true)
            Text(verbatim: segment.title)
                .fontWeight(isFocused ? .semibold : .regular)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: .spaceS)
            Text(verbatim: segment.value)
                .fontWeight(.semibold)
                .monospacedDigit()
            Text(verbatim: segment.percent)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
