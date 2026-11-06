#if DEBUG
    import CoreGraphics
    import Foundation

    struct PortraitMarker: Sendable, Equatable {
        let start: Double
        let duration: Double

        var end: Double { start + duration }
    }

    struct PortraitTransformSlots: Sendable {
        let anchor: Int
        let position: Int
        let scale: Int
        let rotation: Int
        let opacity: Int
    }

    enum PortraitGeometry: Sendable {
        case rect(size: Int, position: Int, radius: Int)
        case ellipse(size: Int, position: Int)
        case bezier(slot: Int, vertices: Int, closed: Bool, steps: [Int])
    }

    enum PortraitPaintSlots: Sendable {
        case fill(color: Int, opacity: Int)
        case stroke(color: Int, opacity: Int, width: Int)
        case gradient(start: Int, end: Int, opacity: Int, from: PortraitRGBA, to: PortraitRGBA)
    }

    indirect enum PortraitItem: Sendable {
        case group(PortraitTransformSlots, [PortraitItem])
        case shape(PortraitGeometry)
        case paint(PortraitPaintSlots)
    }

    struct PortraitNode: Sendable {
        let index: Int
        let name: String
        let parent: Int?
        let span: Range<Double>
        let transform: PortraitTransformSlots
        let items: [PortraitItem]
    }

    struct PortraitRGBA: Sendable, Equatable {
        let red: Double
        let green: Double
        let blue: Double
        let alpha: Double
    }

    struct PortraitSample: Sendable, Equatable {
        var values: [Double]
        var visibility: [Double]

        static func blend(_ from: PortraitSample, _ to: PortraitSample, amount: Double)
            -> PortraitSample
        {
            guard amount < 1 else { return to }
            guard amount > 0 else { return from }
            var mixed = to
            for index in mixed.values.indices {
                let first = from.values[index]
                mixed.values[index] = first + (to.values[index] - first) * amount
            }
            for index in mixed.visibility.indices {
                let first = from.visibility[index]
                mixed.visibility[index] = first + (to.visibility[index] - first) * amount
            }
            return mixed
        }
    }

    struct PortraitScene: Sendable {
        static let curveTolerance = 0.25

        let size: CGSize
        let frameRate: Double
        let markers: [String: PortraitMarker]
        let nodes: [PortraitNode]
        let slotCount: Int
        let positions: [Int: Int]
        private let tracks: [PortraitTrack]
        private let offsets: [Int]

        init(document: [String: Any]) throws {
            guard let width = Self.number(document["w"]), let height = Self.number(document["h"]),
                let frameRate = Self.number(document["fr"]),
                let layers = document["layers"] as? [[String: Any]]
            else { throw PortraitSceneError.malformed("document") }
            if let ddd = Self.number(document["ddd"]), ddd != 0 {
                throw PortraitSceneError.unsupported("3D")
            }
            var builder = PortraitSceneBuilder()
            let nodes = try layers.map { try builder.node($0) }
            size = CGSize(width: width, height: height)
            self.frameRate = frameRate
            markers = Self.markers(document["markers"])
            self.nodes = nodes
            positions = Dictionary(
                nodes.enumerated().map { ($0.element.index, $0.offset) }, uniquingKeysWith: { $1 })
            tracks = builder.tracks
            offsets = builder.offsets
            slotCount = builder.slotCount
        }

        func sample(at frame: Double) -> PortraitSample {
            var values = [Double](repeating: 0, count: slotCount)
            for (track, offset) in zip(tracks, offsets) {
                track.write(at: frame, into: &values, at: offset)
            }
            let visibility = nodes.map { $0.span.contains(frame) ? 1.0 : 0.0 }
            return PortraitSample(values: values, visibility: visibility)
        }

        func node(named name: String) -> PortraitNode? {
            nodes.first { $0.name == name }
        }

        func frame(of marker: String) -> Double? {
            markers[marker]?.start
        }

        private static func markers(_ raw: Any?) -> [String: PortraitMarker] {
            let entries = (raw as? [[String: Any]]) ?? []
            var markers: [String: PortraitMarker] = [:]
            for entry in entries {
                guard let name = entry["cm"] as? String, let start = number(entry["tm"]) else {
                    continue
                }
                markers[name] = PortraitMarker(start: start, duration: number(entry["dr"]) ?? 0)
            }
            return markers
        }

        static func number(_ value: Any?) -> Double? {
            if let value = value as? Double { return value }
            if let value = value as? Int { return Double(value) }
            if let value = value as? NSNumber { return value.doubleValue }
            if let value = value as? [Any], value.count == 1 { return number(value[0]) }
            return nil
        }
    }
#endif
