#if DEBUG
    import CoreGraphics
    import Foundation

    struct PortraitOffsets: Sendable, Equatable {
        private static let turnDepths: [String: Double] = [
            "hairTurn": 0.35, "beardTurn": 0.6, "cheekTurn": 0.9, "glassesTurn": 1.05,
            "noseTurn": 1.25,
        ]
        private static let browEyeShare = 0.3

        var turn = 0.0
        var eyeX = 0.0
        var eyeY = 0.0
        var roll = 0.0

        static let zero = PortraitOffsets()

        func shift(for name: String) -> (x: Double, y: Double, rotation: Double) {
            if let depth = Self.turnDepths[name] { return (turn * depth, 0, 0) }
            switch name {
            case "eyes": return (turn + eyeX, eyeY, 0)
            case "mouth", "mouthOpen": return (turn, 0, 0)
            case "browLeft", "browRight": return (turn + eyeX * Self.browEyeShare, 0, 0)
            case "head": return (0, 0, roll)
            default: return (0, 0, 0)
            }
        }
    }

    struct PortraitContour: Sendable, Equatable {
        let range: Range<Int>
        let closed: Bool
    }

    struct PortraitDrawItem: Sendable {
        enum Paint: Sendable {
            case fill(PortraitRGBA)
            case stroke(PortraitRGBA, width: Double)
            case gradient(start: CGPoint, end: CGPoint, from: PortraitRGBA, to: PortraitRGBA)
        }

        let contours: [PortraitContour]
        let paint: Paint
        let opacity: Double
    }

    struct PortraitFrame: Sendable {
        let size: CGSize
        var points: [CGPoint] = []
        var items: [PortraitDrawItem] = []
    }

    extension PortraitScene {
        private static let invisible = 0.001
        private static let percent = 100.0
        private static let degrees = Double.pi / 180
        private static let minimumEllipseSteps = 8

        func frame(_ sample: PortraitSample, offsets: PortraitOffsets = .zero) -> PortraitFrame {
            var worlds = [CGAffineTransform?](repeating: nil, count: nodes.count)
            var frame = PortraitFrame(size: size)
            for position in nodes.indices.reversed() {
                let node = nodes[position]
                guard !node.items.isEmpty else { continue }
                let opacity =
                    sample.visibility[position] * sample.values[node.transform.opacity]
                    / Self.percent
                guard opacity > Self.invisible else { continue }
                let world = self.world(position, sample, offsets, &worlds)
                emit(node.items, world, opacity, sample.values, into: &frame)
            }
            return frame
        }

        func world(
            _ position: Int, _ sample: PortraitSample, _ offsets: PortraitOffsets,
            _ worlds: inout [CGAffineTransform?]
        ) -> CGAffineTransform {
            if let known = worlds[position] { return known }
            let node = nodes[position]
            let shift = offsets.shift(for: node.name)
            var matrix = Self.matrix(node.transform, sample.values, shift: shift)
            if let parent = node.parent, let parentPosition = positions[parent] {
                matrix = matrix.concatenating(world(parentPosition, sample, offsets, &worlds))
            }
            worlds[position] = matrix
            return matrix
        }

        static func matrix(
            _ slots: PortraitTransformSlots, _ values: [Double],
            shift: (x: Double, y: Double, rotation: Double) = (0, 0, 0)
        ) -> CGAffineTransform {
            let anchor = CGAffineTransform(
                translationX: -values[slots.anchor], y: -values[slots.anchor + 1])
            let scale = CGAffineTransform(
                scaleX: values[slots.scale] / percent, y: values[slots.scale + 1] / percent)
            let rotation = CGAffineTransform(
                rotationAngle: (values[slots.rotation] + shift.rotation) * degrees)
            let position = CGAffineTransform(
                translationX: values[slots.position] + shift.x,
                y: values[slots.position + 1] + shift.y)
            return anchor.concatenating(scale).concatenating(rotation).concatenating(position)
        }

        private func emit(
            _ items: [PortraitItem], _ matrix: CGAffineTransform, _ opacity: Double,
            _ values: [Double], into frame: inout PortraitFrame
        ) {
            for index in items.indices.reversed() {
                switch items[index] {
                case .group(let slots, let children):
                    let groupOpacity = opacity * values[slots.opacity] / Self.percent
                    guard groupOpacity > Self.invisible else { continue }
                    let local = Self.matrix(slots, values)
                    emit(children, local.concatenating(matrix), groupOpacity, values, into: &frame)
                case .shape:
                    continue
                case .paint(let paint):
                    let contours = items[..<index].flatMap { item -> [PortraitContour] in
                        guard case .shape(let geometry) = item else { return [] }
                        return Self.append(geometry, values, matrix, to: &frame.points)
                    }
                    guard !contours.isEmpty else { continue }
                    let (resolved, paintOpacity) = Self.resolve(paint, values, matrix)
                    let total = opacity * paintOpacity
                    guard total > Self.invisible else { continue }
                    frame.items.append(
                        PortraitDrawItem(contours: contours, paint: resolved, opacity: total))
                }
            }
        }

        private static func resolve(
            _ paint: PortraitPaintSlots, _ values: [Double], _ matrix: CGAffineTransform
        ) -> (PortraitDrawItem.Paint, Double) {
            switch paint {
            case .fill(let color, let opacity):
                return (.fill(rgba(values, color)), values[opacity] / percent)
            case .stroke(let color, let opacity, let width):
                let scale = abs(matrix.a * matrix.d - matrix.b * matrix.c).squareRoot()
                return (
                    .stroke(rgba(values, color), width: values[width] * scale),
                    values[opacity] / percent
                )
            case .gradient(let start, let end, let opacity, let from, let to):
                let first = CGPoint(x: values[start], y: values[start + 1]).applying(matrix)
                let last = CGPoint(x: values[end], y: values[end + 1]).applying(matrix)
                return (
                    .gradient(start: first, end: last, from: from, to: to),
                    values[opacity] / percent
                )
            }
        }

        private static func rgba(_ values: [Double], _ slot: Int) -> PortraitRGBA {
            PortraitRGBA(
                red: values[slot], green: values[slot + 1], blue: values[slot + 2],
                alpha: values[slot + 3])
        }

        private static func append(
            _ geometry: PortraitGeometry, _ values: [Double], _ matrix: CGAffineTransform,
            to points: inout [CGPoint]
        ) -> [PortraitContour] {
            let start = points.count
            let closed: Bool
            switch geometry {
            case .rect(let size, let position, let radius):
                rect(
                    center: CGPoint(x: values[position], y: values[position + 1]),
                    size: CGSize(width: values[size], height: values[size + 1]),
                    radius: values[radius], matrix, &points)
                closed = true
            case .ellipse(let size, let position):
                ellipse(
                    center: CGPoint(x: values[position], y: values[position + 1]),
                    size: CGSize(width: values[size], height: values[size + 1]), matrix, &points)
                closed = true
            case .bezier(let slot, let vertices, let isClosed, let steps):
                bezier(slot, vertices, isClosed, steps, values, matrix, &points)
                closed = isClosed
            }
            guard points.count > start else { return [] }
            return [PortraitContour(range: start..<points.count, closed: closed)]
        }

        static func arcSteps(radius: Double, sweep: Double) -> Int {
            guard radius > curveTolerance else { return 1 }
            let step = 2 * acos(1 - curveTolerance / radius)
            return max(1, Int((sweep / step).rounded(.up)))
        }

        private static func rect(
            center: CGPoint, size: CGSize, radius: Double, _ matrix: CGAffineTransform,
            _ points: inout [CGPoint]
        ) {
            let halfWidth = size.width / 2
            let halfHeight = size.height / 2
            let corner = min(max(radius, 0), halfWidth, halfHeight)
            let corners = [
                (CGPoint(x: center.x + halfWidth - corner, y: center.y - halfHeight + corner), -0.5),
                (CGPoint(x: center.x + halfWidth - corner, y: center.y + halfHeight - corner), 0.0),
                (CGPoint(x: center.x - halfWidth + corner, y: center.y + halfHeight - corner), 0.5),
                (CGPoint(x: center.x - halfWidth + corner, y: center.y - halfHeight + corner), 1.0),
            ]
            let steps = corner > 0 ? arcSteps(radius: corner, sweep: .pi / 2) : 0
            for (pivot, turn) in corners {
                let first = turn * .pi
                for step in 0...steps {
                    let angle = first + (Double.pi / 2) * Double(step) / Double(max(steps, 1))
                    points.append(
                        CGPoint(x: pivot.x + corner * cos(angle), y: pivot.y + corner * sin(angle))
                            .applying(matrix))
                }
            }
        }

        private static func ellipse(
            center: CGPoint, size: CGSize, _ matrix: CGAffineTransform, _ points: inout [CGPoint]
        ) {
            let radiusX = size.width / 2
            let radiusY = size.height / 2
            let steps = max(
                minimumEllipseSteps, arcSteps(radius: max(radiusX, radiusY), sweep: 2 * .pi))
            for step in 0..<steps {
                let angle = -Double.pi / 2 + 2 * .pi * Double(step) / Double(steps)
                points.append(
                    CGPoint(x: center.x + radiusX * cos(angle), y: center.y + radiusY * sin(angle))
                        .applying(matrix))
            }
        }

        private static func bezier(
            _ slot: Int, _ count: Int, _ closed: Bool, _ steps: [Int], _ values: [Double],
            _ matrix: CGAffineTransform, _ points: inout [CGPoint]
        ) {
            guard count > 0 else { return }
            func point(_ base: Int, _ index: Int) -> CGPoint {
                CGPoint(x: values[slot + base + index * 2], y: values[slot + base + index * 2 + 1])
            }
            let incoming = count * 2
            let outgoing = count * 4
            for (segment, divisions) in steps.enumerated() {
                let next = (segment + 1) % count
                let start = point(0, segment)
                let end = point(0, next)
                let out = point(outgoing, segment)
                let into = point(incoming, next)
                let control1 = CGPoint(x: start.x + out.x, y: start.y + out.y)
                let control2 = CGPoint(x: end.x + into.x, y: end.y + into.y)
                for step in 0..<divisions {
                    let t = Double(step) / Double(divisions)
                    let u = 1 - t
                    let a = u * u * u
                    let b = 3 * u * u * t
                    let c = 3 * u * t * t
                    let d = t * t * t
                    points.append(
                        CGPoint(
                            x: a * start.x + b * control1.x + c * control2.x + d * end.x,
                            y: a * start.y + b * control1.y + c * control2.y + d * end.y
                        ).applying(matrix))
                }
            }
            if !closed { points.append(point(0, count - 1).applying(matrix)) }
        }
    }
#endif
