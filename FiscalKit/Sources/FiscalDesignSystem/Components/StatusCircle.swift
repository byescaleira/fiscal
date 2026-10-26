import SwiftUI

public struct StatusCircle: View {
    @ScaledMetric(relativeTo: .caption) private var diameter: CGFloat = .badgeS
    private let title: String
    private let symbol: String
    private let color: Color
    private let isDashed: Bool

    public init(_ title: String, symbol: String, color: Color, isDashed: Bool = false) {
        self.title = title
        self.symbol = symbol
        self.color = color
        self.isDashed = isDashed
    }

    public var body: some View {
        Image(systemName: symbol)
            .font(.chipLabel)
            .foregroundStyle(color)
            .frame(width: diameter, height: diameter)
            .background(color.opacity(.opacityTint), in: .circle)
            .overlay {
                if isDashed {
                    Circle().strokeBorder(
                        color,
                        style: StrokeStyle(
                            lineWidth: .spaceHairline / 2, dash: [.space2XS, .spaceHairline]))
                }
            }
            .accessibilityElement()
            .accessibilityLabel(Text(verbatim: title))
    }
}
