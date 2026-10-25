import SwiftUI

public struct Chip: View {
    public enum Shape: Sendable {
        case capsule, tag
    }

    private let text: Text
    private let color: Color
    private let shape: Shape
    private let font: Font

    public init(
        _ key: LocalizedStringKey, color: Color, shape: Shape = .tag, font: Font = .chipLabel
    ) {
        self.init(text: Text(key), color: color, shape: shape, font: font)
    }

    @_disfavoredOverload
    public init<S: StringProtocol>(
        _ text: S, color: Color, shape: Shape = .tag, font: Font = .chipLabel
    ) {
        self.init(text: Text(text), color: color, shape: shape, font: font)
    }

    private init(text: Text, color: Color, shape: Shape, font: Font) {
        self.text = text
        self.color = color
        self.shape = shape
        self.font = font
    }

    public var body: some View {
        let label =
            text
            .font(font)
            .foregroundStyle(color)
            .lineLimit(1)
            .padding(.horizontal, .spaceM)
            .padding(.vertical, shape == .capsule ? .spaceS : .space2XS)
        switch shape {
        case .capsule: label.background(color.opacity(.opacityTint), in: .capsule)
        case .tag: label.background(color.opacity(.opacityTint), in: .rect(cornerRadius: .radiusS))
        }
    }
}
