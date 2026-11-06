#if DEBUG
    import QuartzCore
    import SwiftUI

    enum PortraitClock {
        static var now: Double { CACurrentMediaTime() }
    }

    struct PortraitInteraction: ViewModifier {
        static let slop: CGFloat = 10
        static let accessibilityHold = Duration.seconds(2)
        static let accessibilityLook = Duration.seconds(1)

        let mixer: PortraitMixer
        let isEnabled: Bool
        let onAction: () -> Void
        @State private var size = CGSize.zero
        @State private var touchStart: CGPoint?
        @State private var isLooking = false
        @State private var isHolding = false
        @State private var holdTask: Task<Void, Never>?
        @State private var taps = 0

        func body(content: Content) -> some View {
            content
                .contentShape(.circle)
                .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
                .gesture(touch, isEnabled: isEnabled)
                .sensoryFeedback(.impact(weight: .light), trigger: taps)
                .accessibilityAction(named: Text(verbatim: "Reagir")) { react() }
                .accessibilityAction(named: Text(verbatim: "Pensar")) {
                    Task { await think() }
                }
                .accessibilityAction(named: Text(verbatim: "Olhar para o lado")) {
                    Task { await glance() }
                }
        }

        private var touch: some Gesture {
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if touchStart == nil { begin(at: value.startLocation) }
                    let moved = hypot(value.translation.width, value.translation.height)
                    if moved > Self.slop, !isHolding {
                        holdTask?.cancel()
                    }
                    if moved > Self.slop || isLooking {
                        isLooking = true
                        apply(.look(normalized(value.location)))
                    }
                }
                .onEnded { _ in finish() }
        }

        private func begin(at location: CGPoint) {
            touchStart = location
            holdTask = Task {
                try? await Task.sleep(for: .seconds(PortraitMixer.holdDelay))
                guard !Task.isCancelled else { return }
                isHolding = true
                apply(.holdBegan)
            }
        }

        private func finish() {
            holdTask?.cancel()
            holdTask = nil
            if isHolding {
                apply(.holdEnded)
            } else if !isLooking {
                react()
            }
            if isLooking { apply(.lookEnded) }
            touchStart = nil
            isLooking = false
            isHolding = false
        }

        private func react() {
            apply(.tap)
            taps += 1
        }

        private func think() async {
            apply(.holdBegan)
            try? await Task.sleep(for: Self.accessibilityHold)
            apply(.holdEnded)
        }

        private func glance() async {
            apply(.look(CGPoint(x: 1, y: 0)))
            try? await Task.sleep(for: Self.accessibilityLook)
            apply(.lookEnded)
        }

        private func apply(_ action: PortraitAction) {
            mixer.apply(action, at: PortraitClock.now)
            onAction()
        }

        private func normalized(_ location: CGPoint) -> CGPoint {
            guard size.width > 0, size.height > 0 else { return .zero }
            return CGPoint(
                x: (location.x - size.width / 2) / (size.width / 2),
                y: (location.y - size.height / 2) / (size.height / 2))
        }
    }
#endif
