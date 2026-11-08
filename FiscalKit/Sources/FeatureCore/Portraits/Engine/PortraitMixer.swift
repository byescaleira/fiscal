#if DEBUG
    import CoreGraphics
    import Foundation

    enum PortraitAction: Sendable, Equatable {
        case tap
        case holdBegan
        case holdEnded
        case look(CGPoint)
        case lookEnded
        case tilt(Double)
    }

    struct PortraitLimits: Sendable, Equatable {
        private static let centerX = 100.0
        private static let eyeRestY = 96.0
        private static let hairDepth = 0.35

        let turn: Double
        let eyeX: Double
        let eyeY: Double
        let roll: Double

        init(turn: Double, eyeX: Double, eyeY: Double, roll: Double) {
            self.turn = turn
            self.eyeX = eyeX
            self.eyeY = eyeY
            self.roll = roll
        }

        init(scene: PortraitScene) {
            let eyes = scene.node(named: "eyes")
            let hair = scene.node(named: "hairTurn")
            let head = scene.node(named: "head")
            func frames(_ marker: String) -> [Double] {
                guard let range = scene.markers[marker] else { return [] }
                return stride(from: range.start, through: range.end, by: 1).map { $0 }
            }
            let everyFrame = scene.markers.values.flatMap {
                stride(from: $0.start, through: $0.end, by: 1).map { $0 }
            }
            var turn = 0.0
            var eyeX = 0.0
            for frame in frames("lookAround") {
                let values = scene.sample(at: frame).values
                let currentTurn = hair.map { values[$0.transform.position] / Self.hairDepth } ?? 0
                turn = max(turn, abs(currentTurn))
                if let eyes {
                    eyeX = max(
                        eyeX, abs(values[eyes.transform.position] - Self.centerX - currentTurn))
                }
            }
            var eyeY = 0.0
            if let eyes {
                for frame in everyFrame {
                    let values = scene.sample(at: frame).values
                    eyeY = max(eyeY, abs(values[eyes.transform.position + 1] - Self.eyeRestY))
                }
            }
            var roll = 0.0
            if let head {
                for frame in frames("tilt") {
                    roll = max(roll, abs(scene.sample(at: frame).values[head.transform.rotation]))
                }
            }
            self.init(turn: turn, eyeX: eyeX, eyeY: eyeY, roll: roll)
        }
    }

    @MainActor
    final class PortraitMixer {
        static let idle = "idle"
        static let think = "think"
        static let thinkLoop = "thinkLoop"
        static let reactions = ["wave", "smile", "browRaise"]
        static let holdDelay = 0.5
        static let switchBlend = 0.2
        static let releaseBlend = 0.3
        static let lookReturn = 0.4

        private struct Clip {
            let marker: PortraitMarker
            let name: String
            let loop: PortraitMarker?
            let startedAt: Double
        }

        let scene: PortraitScene
        let limits: PortraitLimits
        private let random: () -> Double
        private var clip: Clip
        private var previous: Clip?
        private var blendStart = 0.0
        private var blendLength = 0.0
        private var look = CGPoint.zero
        private var lookReleasedAt: Double?
        private var lookAtRelease = CGPoint.zero
        private var roll = 0.0
        private var isHolding = false

        init(scene: PortraitScene, random: @escaping () -> Double = { .random(in: 0..<1) }) {
            self.scene = scene
            limits = PortraitLimits(scene: scene)
            self.random = random
            let idle = scene.markers[Self.idle] ?? PortraitMarker(start: 0, duration: 0)
            clip = Clip(marker: idle, name: Self.idle, loop: idle, startedAt: 0)
        }

        var currentMarker: String { clip.name }

        func isActing(at time: Double) -> Bool {
            clip.name != Self.idle || isBlending(at: time) || look != .zero || isHolding
                || lookReleasedAt.map { time - $0 < Self.lookReturn } == true
        }

        func apply(_ action: PortraitAction, at time: Double) {
            settle(at: time)
            switch action {
            case .tap:
                guard !isHolding else { return }
                let index = min(
                    Int(random() * Double(Self.reactions.count)), Self.reactions.count - 1)
                play(Self.reactions[index], loop: nil, at: time, blend: Self.switchBlend)
            case .holdBegan:
                isHolding = true
                play(
                    Self.think, loop: scene.markers[Self.thinkLoop], at: time,
                    blend: Self.switchBlend)
            case .holdEnded:
                guard isHolding else { return }
                isHolding = false
                returnToIdle(at: time, blend: Self.releaseBlend)
            case .look(let point):
                look = CGPoint(x: min(max(point.x, -1), 1), y: min(max(point.y, -1), 1))
                lookReleasedAt = nil
            case .lookEnded:
                lookAtRelease = look
                look = .zero
                lookReleasedAt = time
            case .tilt(let degrees):
                roll = min(max(degrees, -limits.roll), limits.roll)
            }
        }

        func sample(at time: Double) -> PortraitSample {
            settle(at: time)
            let current = scene.sample(at: frame(of: clip, at: time))
            guard let previous, isBlending(at: time) else { return current }
            let amount = (time - blendStart) / blendLength
            return PortraitSample.blend(
                scene.sample(at: frame(of: previous, at: time)), current, amount: amount)
        }

        func offsets(at time: Double) -> PortraitOffsets {
            var gaze = look
            if let released = lookReleasedAt {
                let remaining = max(0, 1 - (time - released) / Self.lookReturn)
                gaze = CGPoint(x: lookAtRelease.x * remaining, y: lookAtRelease.y * remaining)
            }
            return PortraitOffsets(
                turn: gaze.x * limits.turn, eyeX: gaze.x * limits.eyeX,
                eyeY: gaze.y * limits.eyeY, roll: roll)
        }

        func frame(at time: Double) -> PortraitFrame {
            scene.frame(sample(at: time), offsets: offsets(at: time))
        }

        func frameNumber(at time: Double) -> Double {
            frame(of: clip, at: time)
        }

        private func isBlending(at time: Double) -> Bool {
            previous != nil && time - blendStart < blendLength
        }

        private func play(_ name: String, loop: PortraitMarker?, at time: Double, blend: Double) {
            guard let marker = scene.markers[name] else { return }
            previous = clip
            blendStart = time
            blendLength = blend
            clip = Clip(marker: marker, name: name, loop: loop, startedAt: time)
        }

        private func returnToIdle(at time: Double, blend: Double) {
            let idle = scene.markers[Self.idle]
            play(Self.idle, loop: idle, at: time, blend: blend)
        }

        private func settle(at time: Double) {
            guard clip.loop == nil else { return }
            let elapsed = (time - clip.startedAt) * scene.frameRate
            if elapsed >= clip.marker.duration { returnToIdle(at: time, blend: Self.switchBlend) }
        }

        private func frame(of clip: Clip, at time: Double) -> Double {
            let elapsed = max(0, (time - clip.startedAt) * scene.frameRate)
            let reached = clip.marker.start + elapsed
            guard let loop = clip.loop, loop.duration > 0, reached >= loop.start else {
                return min(reached, clip.marker.end)
            }
            return loop.start
                + (reached - loop.start).truncatingRemainder(dividingBy: loop.duration)
        }
    }
#endif
