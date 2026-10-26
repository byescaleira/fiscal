import Charts
import SwiftUI

public struct ShareBarChart: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false
    private let value: Double
    private let color: Color
    private let mirrored: Bool
    private let height: CGFloat

    public init(value: Double, color: Color, mirrored: Bool = false, height: CGFloat = .spaceXS) {
        self.value = ProgressBar.clamped(value)
        self.color = color
        self.mirrored = mirrored
        self.height = height
    }

    public var body: some View {
        let shown = revealed ? value : 0
        Chart {
            BarMark(
                xStart: .value("Start", mirrored ? 1 - shown : 0),
                xEnd: .value("Share", mirrored ? 1 : shown)
            )
            .foregroundStyle(color.gradient)
            .clipShape(.capsule)
        }
        .chartXScale(domain: 0...1, range: .plotDimension(padding: 0))
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartPlotStyle { $0.background(Color.secondary.opacity(.opacityFill)) }
        .frame(height: height)
        .clipShape(.capsule)
        .accessibilityHidden(true)
        .onAppear {
            withAnimation(reduceMotion ? nil : .smooth(duration: 1)) { revealed = true }
        }
    }
}
