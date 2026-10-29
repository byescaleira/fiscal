import FiscalDesignSystem
import SwiftUI

struct TimelineRow<Marker: View, Content: View>: View {
    private let isLast: Bool
    private let spacing: CGFloat
    private let marker: Marker
    private let content: Content

    init(
        isLast: Bool, spacing: CGFloat = .spaceM, @ViewBuilder marker: () -> Marker,
        @ViewBuilder content: () -> Content
    ) {
        self.isLast = isLast
        self.spacing = spacing
        self.marker = marker()
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .top, spacing: spacing) {
            VStack(spacing: .spaceXS) {
                marker
                if !isLast {
                    Capsule()
                        .fill(.tertiary)
                        .frame(width: .spaceHairline)
                        .frame(maxHeight: .infinity)
                        .accessibilityHidden(true)
                }
            }
            content
        }
    }
}
