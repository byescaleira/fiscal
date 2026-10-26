import Charts
import SwiftUI

public struct TallyChart: View {
    public struct Segment: Identifiable, Equatable, Sendable {
        public let id: String
        public let title: String
        public let value: Double
        public let color: Color
        public let dashed: Bool

        public init(id: String, title: String, value: Double, color: Color, dashed: Bool = false) {
            self.id = id
            self.title = title
            self.value = value
            self.color = color
            self.dashed = dashed
        }
    }

    private struct Placed: Identifiable {
        let segment: Segment
        let start: Double
        let end: Double

        var id: String { segment.id }
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false
    @State private var width: CGFloat = 0
    private let segments: [Segment]
    private let height: CGFloat
    private let fill: Double
    private let order: Int
    private let track: Color

    public init(
        segments: [Segment], height: CGFloat = .barHeight, fill: Double = 1, order: Int = 0,
        track: Color = Color.secondary.opacity(.opacityFill)
    ) {
        self.segments = segments.filter { $0.value > 0 }
        self.height = height
        self.fill = ProgressBar.clamped(fill)
        self.order = order
        self.track = track
    }

    public var body: some View {
        Chart(placed) { item in
            BarMark(
                xStart: .value("Start", item.start),
                xEnd: .value("Count", revealed ? item.end : item.start)
            )
            .foregroundStyle(
                item.segment.dashed
                    ? AnyShapeStyle(item.segment.color.opacity(.opacityTint))
                    : AnyShapeStyle(item.segment.color)
            )
            .accessibilityLabel(item.segment.title)
            .accessibilityValue(
                item.segment.value.formatted(.number.precision(.fractionLength(0))))
            if item.segment.dashed {
                RuleMark(
                    xStart: .value("Start", item.start),
                    xEnd: .value("Count", revealed ? item.end : item.start),
                    y: height / 2
                )
                .foregroundStyle(item.segment.color)
                .lineStyle(.dashed)
                .accessibilityHidden(true)
            }
        }
        .chartXScale(domain: 0...domainEnd, range: .plotDimension(padding: 0))
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartPlotStyle { $0.background(track) }
        .frame(height: height)
        .clipShape(.capsule)
        .onGeometryChange(for: CGFloat.self) {
            $0.size.width
        } action: {
            width = $0
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .chartReveal(order)) { revealed = true }
        }
    }

    private var total: Double { segments.reduce(0) { $0 + $1.value } }

    private var domainEnd: Double {
        guard total > 0, fill > 0 else { return 1 }
        return total / fill
    }

    private var placed: [Placed] {
        guard total > 0, fill > 0 else { return [] }
        let gap = width > 0 ? domainEnd * Double(CGFloat.spaceHairline / width) / 2 : 0
        var start = 0.0
        return segments.enumerated().map { index, segment in
            let end = start + segment.value
            let lead = index == 0 ? 0 : gap
            let trail = index == segments.count - 1 ? 0 : gap
            let item = Placed(
                segment: segment, start: start + lead, end: max(start + lead, end - trail))
            start = end
            return item
        }
    }
}
