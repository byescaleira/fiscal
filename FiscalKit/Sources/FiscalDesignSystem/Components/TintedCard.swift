import SwiftUI

extension View {
    public func tintedCard(_ color: Color, radius: CGFloat = .radiusM) -> some View {
        background(color.opacity(.opacityFill), in: .rect(cornerRadius: radius))
    }
}
