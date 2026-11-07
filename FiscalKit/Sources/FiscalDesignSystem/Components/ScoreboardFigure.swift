import SwiftUI

public struct ScoreboardFigure: View {
    @ReducesMotion private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 72
    private let value: String
    private let numeric: Double

    private let scale: CGFloat

    public init(_ value: String, numeric: Double, scale: CGFloat = 1) {
        self.value = value
        self.numeric = numeric
        self.scale = scale
    }

    public var body: some View {
        Text(verbatim: value)
            .font(.emphasis(fixed: size * scale, weight: .heavy))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.4)
            .contentTransition(reduceMotion ? .identity : .numericText(value: numeric))
    }
}
