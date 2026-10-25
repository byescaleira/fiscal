import SwiftUI

extension View {
    public func readableWidth(_ width: CGFloat = .readableColumn) -> some View {
        modifier(ReadableWidth(width: width))
    }
}

private struct ReadableWidth: ViewModifier {
    let width: CGFloat
    @State private var margin: CGFloat?

    func body(content: Content) -> some View {
        content
            .contentMargins(.horizontal, margin, for: .scrollContent)
            .onGeometryChange(for: CGFloat?.self) { proxy in
                let excess = (proxy.size.width - width) / 2
                return excess > 20 ? excess : nil
            } action: {
                margin = $0
            }
    }
}
