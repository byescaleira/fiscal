import SwiftUI

public struct SegmentedBar: View {
    private let count: Int
    private let value: Double
    private let color: Color

    public init(count: Int, value: Double, color: Color) {
        self.count = count
        self.value = value
        self.color = color
    }

    public var body: some View {
        HStack(spacing: .spaceS) {
            ForEach(0..<count, id: \.self) { index in
                ProgressBar(value: value - Double(index), color: color)
            }
        }
        .accessibilityHidden(true)
    }
}
