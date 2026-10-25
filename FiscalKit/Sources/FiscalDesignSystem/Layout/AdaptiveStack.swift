import SwiftUI

public struct AdaptiveStack<Content: View>: View {
    private let alignment: VerticalAlignment
    private let stackedAlignment: HorizontalAlignment
    private let spacing: CGFloat?
    private let content: Content

    public init(
        alignment: VerticalAlignment = .center, stackedAlignment: HorizontalAlignment = .leading,
        spacing: CGFloat? = nil, @ViewBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.stackedAlignment = stackedAlignment
        self.spacing = spacing
        self.content = content()
    }

    public var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: alignment, spacing: spacing) { content }
            VStack(alignment: stackedAlignment, spacing: spacing) { content }
        }
    }
}
