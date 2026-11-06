#if DEBUG
    import Foundation
    import Observation

    #if os(iOS)
        import CoreMotion
    #endif

    @MainActor
    @Observable
    final class PortraitTilt {
        static let rate = 1.0 / 30
        private static let degrees = 180 / Double.pi

        private(set) var roll = 0.0
        private(set) var isLive = false
        @ObservationIgnored private var baseline: Double?

        #if os(iOS)
            @ObservationIgnored private let manager = CMMotionManager()
        #endif

        func start() {
            #if os(iOS)
                guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
                manager.deviceMotionUpdateInterval = Self.rate
                manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
                    guard let gravity = motion?.gravity else { return }
                    let angle = atan2(gravity.x, -gravity.y) * Self.degrees
                    MainActor.assumeIsolated { self?.follow(angle) }
                }
            #endif
        }

        func stop() {
            #if os(iOS)
                manager.stopDeviceMotionUpdates()
            #endif
            isLive = false
            baseline = nil
            roll = 0
        }

        private func follow(_ angle: Double) {
            let reference = baseline ?? angle
            baseline = reference
            roll = angle - reference
            isLive = true
        }
    }
#endif
