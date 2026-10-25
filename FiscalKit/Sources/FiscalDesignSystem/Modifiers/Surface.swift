import SwiftUI

extension View {
    public func surface(
        tint: Color? = nil, in shape: some InsettableShape, interactive: Bool = false
    ) -> some View {
        modifier(GlassSurface(tint: tint, shape: shape, interactive: interactive))
    }

    public func clearSurface(in shape: some InsettableShape) -> some View {
        modifier(ClearSurface(shape: shape))
    }

    public func contentSurface(tint: Color? = nil, in shape: some Shape) -> some View {
        background(tint ?? .subtleFill, in: shape)
    }
}

private struct ClearSurface<S: InsettableShape>: ViewModifier {
    let shape: S

    func body(content: Content) -> some View {
        #if os(visionOS)
            content.glassBackgroundEffect(in: shape)
        #else
            content.glassEffect(.clear, in: shape)
        #endif
    }
}

private struct GlassSurface<S: InsettableShape>: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled
    let tint: Color?
    let shape: S
    let interactive: Bool

    func body(content: Content) -> some View {
        #if os(visionOS)
            content.background(tint ?? .clear, in: shape).glassBackgroundEffect(in: shape)
        #else
            content.glassEffect(
                .regular.tint(tint).interactive(interactive && isEnabled), in: shape)
        #endif
    }
}
