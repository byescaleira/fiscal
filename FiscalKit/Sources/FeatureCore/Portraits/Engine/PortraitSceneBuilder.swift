#if DEBUG
    import Foundation

    struct PortraitSceneBuilder {
        private static let layerKeys: Set<String> = [
            "ddd", "ind", "ty", "nm", "sr", "ao", "ip", "op", "st", "bm", "ks", "shapes", "parent",
            "fx",
        ]
        private static let shapeLayer = 4
        private static let nullLayer = 3
        private static let linearGradient = 1
        private static let nonZero = 1
        private static let roundCap = 2
        private static let roundJoin = 2

        var tracks: [PortraitTrack] = []
        var offsets: [Int] = []
        var slotCount = 0

        mutating func node(_ layer: [String: Any]) throws -> PortraitNode {
            if let extra = layer.keys.first(where: { !Self.layerKeys.contains($0) }) {
                throw PortraitSceneError.unsupported("layer key \(extra)")
            }
            guard let type = PortraitScene.number(layer["ty"]).map(Int.init),
                let index = PortraitScene.number(layer["ind"]).map(Int.init),
                let start = PortraitScene.number(layer["ip"]),
                let end = PortraitScene.number(layer["op"]),
                let transform = layer["ks"] as? [String: Any]
            else { throw PortraitSceneError.malformed("layer") }
            guard type == Self.shapeLayer || type == Self.nullLayer else {
                throw PortraitSceneError.unsupported("layer type \(type)")
            }
            if let mode = PortraitScene.number(layer["bm"]), mode != 0 {
                throw PortraitSceneError.unsupported("blend mode \(Int(mode))")
            }
            if let stretch = PortraitScene.number(layer["sr"]), stretch != 1 {
                throw PortraitSceneError.unsupported("time stretch")
            }
            if let offset = PortraitScene.number(layer["st"]), offset != 0 {
                throw PortraitSceneError.unsupported("start time")
            }
            let shapes = (layer["shapes"] as? [[String: Any]]) ?? []
            return PortraitNode(
                index: index, name: (layer["nm"] as? String) ?? "",
                parent: PortraitScene.number(layer["parent"]).map(Int.init),
                span: start..<end, transform: try self.transform(transform),
                items: try items(shapes))
        }

        private mutating func items(_ shapes: [[String: Any]]) throws -> [PortraitItem] {
            try shapes.compactMap { shape -> PortraitItem? in
                guard let type = shape["ty"] as? String else {
                    throw PortraitSceneError.malformed("shape")
                }
                switch type {
                case "tr":
                    return nil
                case "gr":
                    let children = (shape["it"] as? [[String: Any]]) ?? []
                    let transform = children.first { $0["ty"] as? String == "tr" } ?? [:]
                    return .group(try self.transform(transform), try items(children))
                case "rc":
                    try direction(shape)
                    return .shape(
                        .rect(
                            size: try slot(shape["s"], width: 2),
                            position: try slot(shape["p"], width: 2),
                            radius: try slot(shape["r"], width: 1, fallback: [0])))
                case "el":
                    try direction(shape)
                    return .shape(
                        .ellipse(
                            size: try slot(shape["s"], width: 2),
                            position: try slot(shape["p"], width: 2)))
                case "sh":
                    try direction(shape)
                    return .shape(try bezier(shape["ks"]))
                case "fl":
                    try fillRule(shape)
                    return .paint(
                        .fill(
                            color: try slot(shape["c"], width: 4),
                            opacity: try slot(shape["o"], width: 1, fallback: [100])))
                case "st":
                    guard PortraitScene.number(shape["lc"]).map(Int.init) == Self.roundCap,
                        PortraitScene.number(shape["lj"]).map(Int.init) == Self.roundJoin
                    else { throw PortraitSceneError.unsupported("stroke cap or join") }
                    return .paint(
                        .stroke(
                            color: try slot(shape["c"], width: 4),
                            opacity: try slot(shape["o"], width: 1, fallback: [100]),
                            width: try slot(shape["w"], width: 1)))
                case "gf":
                    try fillRule(shape)
                    guard PortraitScene.number(shape["t"]).map(Int.init) == Self.linearGradient
                    else { throw PortraitSceneError.unsupported("radial gradient") }
                    let (from, to) = try stops(shape["g"])
                    return .paint(
                        .gradient(
                            start: try slot(shape["s"], width: 2),
                            end: try slot(shape["e"], width: 2),
                            opacity: try slot(shape["o"], width: 1, fallback: [100]),
                            from: from, to: to))
                default:
                    throw PortraitSceneError.unsupported("shape \(type)")
                }
            }
        }

        private mutating func transform(_ raw: [String: Any]) throws -> PortraitTransformSlots {
            if let skew = raw["sk"] as? [String: Any], PortraitScene.number(skew["k"]) != 0 {
                throw PortraitSceneError.unsupported("skew")
            }
            return PortraitTransformSlots(
                anchor: try slot(raw["a"], width: 2, fallback: [0, 0]),
                position: try slot(raw["p"], width: 2, fallback: [0, 0]),
                scale: try slot(raw["s"], width: 2, fallback: [100, 100]),
                rotation: try slot(raw["r"], width: 1, fallback: [0]),
                opacity: try slot(raw["o"], width: 1, fallback: [100]))
        }

        private func direction(_ shape: [String: Any]) throws {
            if let direction = PortraitScene.number(shape["d"]), direction == 3 {
                throw PortraitSceneError.unsupported("reversed path")
            }
        }

        private func fillRule(_ shape: [String: Any]) throws {
            if let rule = PortraitScene.number(shape["r"]).map(Int.init), rule != Self.nonZero {
                throw PortraitSceneError.unsupported("even-odd fill")
            }
        }

        private mutating func slot(_ raw: Any?, width: Int, fallback: [Double]? = nil) throws
            -> Int
        {
            let track: PortraitTrack
            if let property = raw as? [String: Any] {
                track = try self.track(property, width: width)
            } else if let fallback {
                track = PortraitTrack(constant: fallback)
            } else {
                throw PortraitSceneError.malformed("property")
            }
            return append(track)
        }

        private mutating func append(_ track: PortraitTrack) -> Int {
            let offset = slotCount
            tracks.append(track)
            offsets.append(offset)
            slotCount += track.width
            return offset
        }

        private func track(_ property: [String: Any], width: Int) throws -> PortraitTrack {
            let animated = PortraitScene.number(property["a"]).map(Int.init) == 1
            guard animated else {
                return PortraitTrack(constant: try Self.vector(property["k"], width: width))
            }
            guard let keys = property["k"] as? [[String: Any]] else {
                throw PortraitSceneError.malformed("keyframes")
            }
            var frames: [Double] = []
            var values: [[Double]] = []
            for (position, key) in keys.enumerated() {
                if let hold = PortraitScene.number(key["h"]), hold == 1 {
                    throw PortraitSceneError.unsupported("hold keyframe")
                }
                if position < keys.count - 1 { try Self.requireLinear(key) }
                guard let frame = PortraitScene.number(key["t"]) else {
                    throw PortraitSceneError.malformed("keyframe time")
                }
                frames.append(frame)
                values.append(try Self.vector(key["s"], width: width))
            }
            return try PortraitTrack(frames: frames, values: values)
        }

        private mutating func bezier(_ raw: Any?) throws -> PortraitGeometry {
            guard let property = raw as? [String: Any] else {
                throw PortraitSceneError.malformed("path")
            }
            let animated = PortraitScene.number(property["a"]).map(Int.init) == 1
            let rawShapes: [Any]
            var frames: [Double] = []
            if animated {
                guard let keys = property["k"] as? [[String: Any]] else {
                    throw PortraitSceneError.malformed("path keyframes")
                }
                for (position, key) in keys.enumerated() {
                    if let hold = PortraitScene.number(key["h"]), hold == 1 {
                        throw PortraitSceneError.unsupported("hold keyframe")
                    }
                    if position < keys.count - 1 { try Self.requireLinear(key) }
                    frames.append(PortraitScene.number(key["t"]) ?? 0)
                }
                rawShapes = keys.map { key in (key["s"] as? [Any])?.first ?? key["s"] as Any }
            } else {
                rawShapes = [property["k"] as Any]
            }
            let shapes = try rawShapes.map(PortraitBezierValue.init)
            guard let first = shapes.first,
                shapes.allSatisfy({
                    $0.vertices.count == first.vertices.count && $0.closed == first.closed
                })
            else { throw PortraitSceneError.unsupported("path with changing vertices") }
            let track =
                animated
                ? try PortraitTrack(frames: frames, values: shapes.map(\.flat))
                : PortraitTrack(constant: first.flat)
            let steps = PortraitBezierValue.steps(
                shapes, closed: first.closed, tolerance: PortraitScene.curveTolerance)
            return .bezier(
                slot: append(track), vertices: first.vertices.count, closed: first.closed,
                steps: steps)
        }

        private static func requireLinear(_ key: [String: Any]) throws {
            let outgoing = key["o"] as? [String: Any]
            let incoming = key["i"] as? [String: Any]
            let outX = (outgoing?["x"] as? [Any])?.compactMap(PortraitScene.number) ?? [0]
            let outY = (outgoing?["y"] as? [Any])?.compactMap(PortraitScene.number) ?? [0]
            let inX = (incoming?["x"] as? [Any])?.compactMap(PortraitScene.number) ?? [1]
            let inY = (incoming?["y"] as? [Any])?.compactMap(PortraitScene.number) ?? [1]
            let linear =
                outX.allSatisfy { $0 == 0 } && outY.allSatisfy { $0 == 0 }
                && inX.allSatisfy { $0 == 1 } && inY.allSatisfy { $0 == 1 }
            guard linear else { throw PortraitSceneError.unsupported("eased keyframe") }
        }

        private static func vector(_ raw: Any?, width: Int) throws -> [Double] {
            if let single = PortraitScene.number(raw), width == 1 { return [single] }
            guard let list = raw as? [Any] else { throw PortraitSceneError.malformed("value") }
            let numbers = list.compactMap(PortraitScene.number)
            guard numbers.count >= width else { throw PortraitSceneError.malformed("value") }
            return Array(numbers.prefix(width))
        }

        private func stops(_ raw: Any?) throws -> (PortraitRGBA, PortraitRGBA) {
            guard let gradient = raw as? [String: Any],
                let count = PortraitScene.number(gradient["p"]).map(Int.init),
                let property = gradient["k"] as? [String: Any],
                PortraitScene.number(property["a"]).map(Int.init) != 1,
                let numbers = (property["k"] as? [Any])?.compactMap(PortraitScene.number)
            else { throw PortraitSceneError.unsupported("animated gradient") }
            guard count == 2, numbers.count == 8 || numbers.count == 12,
                numbers[0] == 0, numbers[4] == 1
            else { throw PortraitSceneError.unsupported("gradient stops") }
            var alphas = (1.0, 1.0)
            if numbers.count == 12 {
                guard numbers[8] == 0, numbers[10] == 1 else {
                    throw PortraitSceneError.unsupported("gradient alpha stops")
                }
                alphas = (numbers[9], numbers[11])
            }
            return (
                PortraitRGBA(
                    red: numbers[1], green: numbers[2], blue: numbers[3], alpha: alphas.0),
                PortraitRGBA(
                    red: numbers[5], green: numbers[6], blue: numbers[7], alpha: alphas.1)
            )
        }
    }

    struct PortraitBezierValue {
        let closed: Bool
        let vertices: [[Double]]
        let incoming: [[Double]]
        let outgoing: [[Double]]

        init(_ raw: Any) throws {
            guard let shape = raw as? [String: Any],
                let vertices = shape["v"] as? [[Any]],
                let incoming = shape["i"] as? [[Any]],
                let outgoing = shape["o"] as? [[Any]],
                vertices.count == incoming.count, vertices.count == outgoing.count
            else { throw PortraitSceneError.malformed("path value") }
            closed = (shape["c"] as? Bool) ?? false
            self.vertices = vertices.map { $0.compactMap(PortraitScene.number) }
            self.incoming = incoming.map { $0.compactMap(PortraitScene.number) }
            self.outgoing = outgoing.map { $0.compactMap(PortraitScene.number) }
            guard (self.vertices + self.incoming + self.outgoing).allSatisfy({ $0.count == 2 })
            else { throw PortraitSceneError.malformed("path point") }
        }

        var flat: [Double] {
            vertices.flatMap { $0 } + incoming.flatMap { $0 } + outgoing.flatMap { $0 }
        }

        static func steps(_ shapes: [PortraitBezierValue], closed: Bool, tolerance: Double)
            -> [Int]
        {
            guard let count = shapes.first?.vertices.count, count > 1 else { return [] }
            let segments = closed ? count : count - 1
            return (0..<segments).map { segment in
                let next = (segment + 1) % count
                let flatness = shapes.map { shape -> Double in
                    let start = shape.vertices[segment]
                    let end = shape.vertices[next]
                    let control1 = zip(start, shape.outgoing[segment]).map(+)
                    let control2 = zip(end, shape.incoming[next]).map(+)
                    let first = zip(zip(start, control1), control2).map { $0.0 - 2 * $0.1 + $1 }
                    let second = zip(zip(control1, control2), end).map { $0.0 - 2 * $0.1 + $1 }
                    return max(hypot(first[0], first[1]), hypot(second[0], second[1]))
                }.max() ?? 0
                guard flatness > 0 else { return 1 }
                return max(1, Int((0.75 * flatness / tolerance).squareRoot().rounded(.up)))
            }
        }
    }
#endif
