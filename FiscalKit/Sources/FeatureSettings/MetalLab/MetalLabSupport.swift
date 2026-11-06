#if DEBUG
    import FeatureCore
    import FiscalDesignSystem
    import SwiftUI

    #if canImport(CoreMotion) && os(iOS)
        import CoreMotion
    #endif

    enum MetalLab {
        static let library = ShaderLibrary.bundle(.module)
        nonisolated static let likeSpace = "likeCard"
        static let rippleDuration = 1.6
        static let burstDuration = 0.7
        static let revealSeconds = 2.2
        static let tiltRate = 1.0 / 30
        static let tiltLimit = 1.0
        static let tiltGain = 2.5
        static let dragTiltScale = 160.0
        static let meterWindow = 1.0
        static let millisecondsPerSecond = 1000.0
        static let renderScale: CGFloat = 3
        static let paperGrain: Float = 0.06
        static let paperFiber: Float = 0.035
        static let sheenStrength: Float = 0.42
        static let rippleAmplitude: Float = 12
        static let rippleFrequency: Float = 15
        static let rippleDecay: Float = 8
        static let rippleSpeed: Float = 1200
        static let rippleOffset = CGSize(width: 24, height: 24)
        static let plenaryAspect: CGFloat = 2
        static let cardAspect: CGFloat = 4.0 / 5.0
        static let markerWidth: CGFloat = 1.5

        static func compile() async {
            let none = Shader.Argument.float2(CGSize.zero)
            let one = Shader.Argument.float(1)
            try? await library.labRipple(none, one, one, one, one, one).compile(as: .layerEffect)
            try? await library.labBurst(none, one, one, .color(.clear)).compile(as: .colorEffect)
            try? await library.labPaper(none, one, one, one, none).compile(as: .colorEffect)
            try? await library.labSheen(none, none, one, one).compile(as: .colorEffect)
        }
    }

    struct MotionGate: Equatable {
        let reduceMotion: Bool
        let lowPower: Bool
        let thermal: ProcessInfo.ThermalState

        var isOpen: Bool {
            !reduceMotion && !lowPower
                && thermal.rawValue < ProcessInfo.ThermalState.serious.rawValue
        }

        var summary: String {
            let thermalText: String
            switch thermal {
            case .nominal: thermalText = "normal"
            case .fair: thermalText = "morno"
            case .serious: thermalText = "quente"
            case .critical: thermalText = "crítico"
            @unknown default: thermalText = "—"
            }
            return [
                "Reduzir movimento: \(reduceMotion ? "sim" : "não")",
                "Pouca Energia: \(lowPower ? "sim" : "não")",
                "Temperatura: \(thermalText)",
            ].joined(separator: " · ")
        }
    }

    struct MotionGateReader<Content: View>: View {
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        @State private var thermal = ProcessInfo.processInfo.thermalState
        private let content: (MotionGate) -> Content

        init(@ViewBuilder content: @escaping (MotionGate) -> Content) {
            self.content = content
        }

        var body: some View {
            content(MotionGate(reduceMotion: reduceMotion, lowPower: lowPower, thermal: thermal))
                .onReceive(
                    NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)
                ) { _ in
                    lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
                }
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: ProcessInfo.thermalStateDidChangeNotification)
                ) { _ in
                    thermal = ProcessInfo.processInfo.thermalState
                }
        }
    }

    @MainActor @Observable
    final class FrameMeter {
        private(set) var framesPerSecond = 0
        private(set) var worstMilliseconds = 0.0
        @ObservationIgnored private var frames = 0
        @ObservationIgnored private var windowStart = Date.now
        @ObservationIgnored private var lastFrame: Date?
        @ObservationIgnored private var worst = 0.0

        var summary: String {
            guard framesPerSecond > .zero else { return "Medindo os quadros…" }
            let worstText = worstMilliseconds.formatted(.number.precision(.fractionLength(1)))
            return "\(framesPerSecond) quadros/s · pior quadro \(worstText) ms"
        }

        func tick(_ date: Date) {
            if let lastFrame { worst = max(worst, date.timeIntervalSince(lastFrame)) }
            lastFrame = date
            frames += 1
            let elapsed = date.timeIntervalSince(windowStart)
            guard elapsed >= MetalLab.meterWindow else { return }
            framesPerSecond = Int((Double(frames) / elapsed).rounded())
            worstMilliseconds = worst * MetalLab.millisecondsPerSecond
            frames = .zero
            worst = .zero
            windowStart = date
        }

        func reset() {
            lastFrame = nil
            frames = .zero
            worst = .zero
            windowStart = .now
        }
    }

    struct FrameMeterLabel: View {
        let meter: FrameMeter
        let gate: MotionGate

        var body: some View {
            VStack(alignment: .leading, spacing: .space2XS) {
                Text(verbatim: meter.summary).monospacedDigit()
                Text(verbatim: gate.summary)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    @MainActor @Observable
    final class TiltSource {
        private(set) var tilt = CGPoint.zero
        private(set) var isLive = false
        @ObservationIgnored private var baseline: CGPoint?

        #if canImport(CoreMotion) && os(iOS)
            @ObservationIgnored private let manager = CMMotionManager()
        #endif

        func start() {
            #if canImport(CoreMotion) && os(iOS)
                guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
                manager.deviceMotionUpdateInterval = MetalLab.tiltRate
                manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
                    guard let gravity = motion?.gravity else { return }
                    MainActor.assumeIsolated {
                        self?.follow(CGPoint(x: gravity.x, y: gravity.y))
                    }
                }
            #endif
        }

        private func follow(_ gravity: CGPoint) {
            let reference = baseline ?? gravity
            baseline = reference
            let limit = MetalLab.tiltLimit
            tilt = CGPoint(
                x: min(max((gravity.x - reference.x) * MetalLab.tiltGain, -limit), limit),
                y: min(max((gravity.y - reference.y) * MetalLab.tiltGain, -limit), limit))
            isLive = true
        }

        func stop() {
            #if canImport(CoreMotion) && os(iOS)
                manager.stopDeviceMotionUpdates()
            #endif
            isLive = false
            baseline = nil
            tilt = .zero
        }

        func drag(_ translation: CGSize) {
            let limit = MetalLab.tiltLimit
            tilt = CGPoint(
                x: min(max(translation.width / MetalLab.dragTiltScale, -limit), limit),
                y: min(max(translation.height / MetalLab.dragTiltScale, -limit), limit))
        }

        func settle() {
            guard !isLive else { return }
            tilt = .zero
        }
    }
#endif
