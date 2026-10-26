import SwiftUI

public struct TallyBar: View {
    public struct Segment: Identifiable, Sendable {
        public let id: String
        public let value: Double
        public let color: Color
        public let dashed: Bool

        public init(id: String, value: Double, color: Color, dashed: Bool = false) {
            self.id = id
            self.value = value
            self.color = color
            self.dashed = dashed
        }
    }

    private let segments: [Segment]
    private let height: CGFloat
    private let fill: Double

    public init(segments: [Segment], height: CGFloat = .barHeight, fill: Double = 1) {
        self.segments = segments.filter { $0.value > 0 }
        self.height = height
        self.fill = ProgressBar.clamped(fill)
    }

    public var body: some View {
        GeometryReader { proxy in
            let total = segments.reduce(0) { $0 + $1.value }
            let width = proxy.size.width * fill
            HStack(spacing: .spaceHairline) {
                ForEach(segments) { segment in
                    SegmentShape(segment: segment)
                        .frame(width: segmentWidth(segment, total: total, width: width))
                }
            }
            .frame(width: proxy.size.width, alignment: .leading)
        }
        .frame(height: height)
        .background(Color.secondary.opacity(.opacityFill), in: .capsule)
        .clipShape(.capsule)
        .accessibilityHidden(true)
    }

    private func segmentWidth(_ segment: Segment, total: Double, width: CGFloat) -> CGFloat {
        guard total > 0 else { return 0 }
        let gaps = CGFloat(max(segments.count - 1, 0)) * .spaceHairline
        return max(0, (width - gaps) * segment.value / total)
    }
}

private struct SegmentShape: View {
    let segment: TallyBar.Segment

    var body: some View {
        if segment.dashed {
            Rectangle()
                .fill(segment.color.opacity(.opacityTint))
                .overlay { Rectangle().strokeBorder(segment.color, style: .dashed) }
        } else {
            Rectangle().fill(segment.color)
        }
    }
}

extension StrokeStyle {
    public static let dashed = StrokeStyle(lineWidth: 1, dash: [3, 2])
}
