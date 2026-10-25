import SwiftUI

public struct SymbolBadge: View {
    public enum Style: Sendable {
        case tinted, filled
    }

    private let symbol: String
    private let color: Color
    private let size: CGFloat
    private let style: Style

    public init(_ symbol: String, color: Color, size: CGFloat = .badgeL, style: Style = .tinted) {
        self.symbol = symbol
        self.color = color
        self.size = size
        self.style = style
    }

    public var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(style == .filled ? Color.white : color)
            .frame(width: size, height: size)
            .background(
                style == .filled
                    ? AnyShapeStyle(color.gradient) : AnyShapeStyle(color.opacity(.opacityTint)),
                in: .circle
            )
            .accessibilityHidden(true)
    }
}
