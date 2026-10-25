import SwiftUI

public struct ScoreboardFigure: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 72
    private let value: String
    private let numeric: Double

    public init(_ value: String, numeric: Double) {
        self.value = value
        self.numeric = numeric
    }

    public var body: some View {
        Text(verbatim: value)
            .font(.system(size: size, weight: .heavy).width(.condensed))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.4)
            .contentTransition(reduceMotion ? .identity : .numericText(value: numeric))
    }
}
