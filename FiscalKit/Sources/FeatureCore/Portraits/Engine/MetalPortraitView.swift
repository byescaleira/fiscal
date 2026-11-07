#if DEBUG
    import MetalKit
    import SwiftUI

    struct MetalPortraitView: View {
        let mixer: PortraitMixer
        let renderer: MetalPortraitRenderer
        let isAnimated: Bool
        @State private var isVisible = true

        var body: some View {
            MetalPortraitSurface(
                mixer: mixer, renderer: renderer, isRunning: isAnimated && isVisible
            )
            .modifier(PortraitInteraction(mixer: mixer, isEnabled: isAnimated) {})
            .onScrollVisibilityChange { isVisible = $0 }
            .onAppear { isVisible = true }
            .onDisappear { isVisible = false }
        }
    }

    @MainActor
    final class MetalPortraitCoordinator: NSObject, MTKViewDelegate {
        static let idleRate = 30
        static let fallbackRate = 60

        var mixer: PortraitMixer
        var isRunning: Bool
        let renderer: MetalPortraitRenderer
        private let buffers = MetalPortraitBuffers()

        init(mixer: PortraitMixer, renderer: MetalPortraitRenderer, isRunning: Bool) {
            self.mixer = mixer
            self.renderer = renderer
            self.isRunning = isRunning
        }

        func configure(_ view: MTKView) {
            view.device = renderer.device
            view.delegate = self
            view.colorPixelFormat = MetalPortraitRenderer.colorFormat
            view.depthStencilPixelFormat = MetalPortraitRenderer.stencilFormat
            view.sampleCount = MetalPortraitRenderer.sampleCount
            view.clearColor = MetalPortraitRenderer.transparent
            view.clearStencil = 0
            view.preferredFramesPerSecond = Self.idleRate
            (view.layer as? CAMetalLayer)?.colorspace = CGColorSpace(name: CGColorSpace.sRGB)
            #if os(macOS)
                view.layer?.isOpaque = false
            #else
                view.isOpaque = false
                view.backgroundColor = .clear
            #endif
            update(view)
        }

        func update(_ view: MTKView) {
            view.isPaused = !isRunning
            view.enableSetNeedsDisplay = !isRunning
            if !isRunning { redraw(view) }
        }

        private func redraw(_ view: MTKView) {
            #if os(macOS)
                view.needsDisplay = true
            #else
                view.setNeedsDisplay()
            #endif
        }

        nonisolated func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            MainActor.assumeIsolated {
                if !isRunning { redraw(view) }
            }
        }

        nonisolated func draw(in view: MTKView) {
            MainActor.assumeIsolated { render(view) }
        }

        private func render(_ view: MTKView) {
            let time = PortraitClock.now
            let frame =
                isRunning
                ? mixer.frame(at: time) : mixer.scene.frame(mixer.scene.sample(at: 0))
            view.preferredFramesPerSecond =
                isRunning && mixer.isActing(at: time) ? maximumRate(view) : Self.idleRate
            guard let pass = view.currentRenderPassDescriptor,
                let drawable = view.currentDrawable,
                let commands = renderer.queue.makeCommandBuffer(),
                let encoder = commands.makeRenderCommandEncoder(descriptor: pass)
            else { return }
            renderer.encode(frame, into: encoder, buffers: buffers)
            encoder.endEncoding()
            renderer.track(commands, buffers: buffers)
            commands.present(drawable)
            commands.commit()
        }

        private func maximumRate(_ view: MTKView) -> Int {
            #if os(iOS)
                view.window?.windowScene?.screen.maximumFramesPerSecond ?? Self.fallbackRate
            #elseif os(macOS)
                view.window?.screen?.maximumFramesPerSecond ?? Self.fallbackRate
            #else
                Self.fallbackRate
            #endif
        }
    }

    #if os(macOS)
        struct MetalPortraitSurface: NSViewRepresentable {
            let mixer: PortraitMixer
            let renderer: MetalPortraitRenderer
            let isRunning: Bool

            func makeCoordinator() -> MetalPortraitCoordinator {
                MetalPortraitCoordinator(mixer: mixer, renderer: renderer, isRunning: isRunning)
            }

            func makeNSView(context: Context) -> MTKView {
                let view = MTKView(frame: .zero, device: renderer.device)
                context.coordinator.configure(view)
                return view
            }

            func updateNSView(_ view: MTKView, context: Context) {
                context.coordinator.mixer = mixer
                context.coordinator.isRunning = isRunning
                context.coordinator.update(view)
            }
        }
    #else
        struct MetalPortraitSurface: UIViewRepresentable {
            let mixer: PortraitMixer
            let renderer: MetalPortraitRenderer
            let isRunning: Bool

            func makeCoordinator() -> MetalPortraitCoordinator {
                MetalPortraitCoordinator(mixer: mixer, renderer: renderer, isRunning: isRunning)
            }

            func makeUIView(context: Context) -> MTKView {
                let view = MTKView(frame: .zero, device: renderer.device)
                context.coordinator.configure(view)
                return view
            }

            func updateUIView(_ view: MTKView, context: Context) {
                context.coordinator.mixer = mixer
                context.coordinator.isRunning = isRunning
                context.coordinator.update(view)
            }
        }
    #endif
#endif
