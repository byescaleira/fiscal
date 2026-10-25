import SwiftUI

public struct SurfaceContainer<Content: View>: View {
    private let content: Content
    private let spacing: CGFloat

    public init(spacing: CGFloat = 0, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    public var body: some View {
        #if os(visionOS)
            content
        #else
            GlassEffectContainer(spacing: spacing) { content }
        #endif
    }
}
