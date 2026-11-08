#if DEBUG
    import SwiftUI

    struct CanvasPortraitView: View {
        static let idleInterval = 1.0 / 30

        let mixer: PortraitMixer
        let isAnimated: Bool
        @State private var isActing = false
        @State private var isVisible = true

        var body: some View {
            TimelineView(
                .animation(
                    minimumInterval: isActing ? nil : Self.idleInterval,
                    paused: !isAnimated || !isVisible)
            ) { timeline in
                let frame =
                    isAnimated
                    ? mixer.frame(at: PortraitClock.now)
                    : mixer.scene.frame(mixer.scene.sample(at: 0))
                Canvas { context, size in
                    PortraitPainter.draw(frame, in: &context, size: size)
                }
                .onChange(of: timeline.date) {
                    isActing = mixer.isActing(at: PortraitClock.now)
                }
            }
            .modifier(PortraitInteraction(mixer: mixer, isEnabled: isAnimated) { isActing = true })
            .onScrollVisibilityChange { isVisible = $0 }
            .onAppear { isVisible = true }
            .onDisappear { isVisible = false }
        }
    }

    enum PortraitPainter {
        static func draw(_ frame: PortraitFrame, in context: inout GraphicsContext, size: CGSize) {
            guard frame.size.width > 0, frame.size.height > 0 else { return }
            context.scaleBy(x: size.width / frame.size.width, y: size.height / frame.size.height)
            for item in frame.items {
                var path = Path()
                for contour in item.contours {
                    path.addLines(Array(frame.points[contour.range]))
                    if contour.closed { path.closeSubpath() }
                }
                var layer = context
                layer.opacity = item.opacity
                switch item.paint {
                case .fill(let rgba):
                    layer.fill(path, with: .color(color(rgba)))
                case .stroke(let rgba, let width):
                    layer.stroke(
                        path, with: .color(color(rgba)),
                        style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
                case .gradient(let start, let end, let from, let to):
                    layer.fill(
                        path,
                        with: .linearGradient(
                            Gradient(colors: [color(from), color(to)]), startPoint: start,
                            endPoint: end))
                }
            }
        }

        @MainActor
        static func still(_ frame: PortraitFrame, side: CGFloat) -> CGImage? {
            let renderer = ImageRenderer(
                content: Canvas { context, size in draw(frame, in: &context, size: size) }
                    .frame(width: side, height: side))
            renderer.scale = 1
            return renderer.cgImage
        }

        private static func color(_ rgba: PortraitRGBA) -> Color {
            Color(.sRGB, red: rgba.red, green: rgba.green, blue: rgba.blue, opacity: rgba.alpha)
        }
    }
#endif
