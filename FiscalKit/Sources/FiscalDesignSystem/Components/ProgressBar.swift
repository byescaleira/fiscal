import SwiftUI

public struct ProgressBar: View {
    private let value: Double
    private let color: Color

    public init(value: Double, color: Color) {
        self.value = Self.clamped(value)
        self.color = color
    }

    nonisolated public static func clamped(_ value: Double) -> Double {
        value.isNaN ? 0 : min(max(value, 0), 1)
    }

    public var body: some View {
        #if os(tvOS)
            ProgressView(value: value).tint(color)
        #else
            Gauge(value: value) {
                EmptyView()
            }
            .gaugeStyle(.linearCapacity)
            .tint(color)
            .labelsHidden()
            .accessibilityHidden(true)
        #endif
    }
}
