import Foundation
import SwiftUI

public struct MapOutline: Codable, Sendable, Hashable {
    public let width: Double
    public let height: Double
    public let rings: [[[Double]]]

    public init(width: Double, height: Double, rings: [[[Double]]]) {
        self.width = width
        self.height = height
        self.rings = rings
    }

    public var aspectRatio: Double {
        height > 0 ? width / height : 1
    }

    public var pointCount: Int {
        rings.reduce(0) { $0 + $1.count }
    }
}

public struct BrazilMap: Codable, Sendable, Hashable {
    public struct Source: Codable, Sendable, Hashable {
        public let name: String
        public let url: URL
        public let fetchedAt: String
        public let note: String
    }

    public struct Country: Codable, Sendable, Hashable {
        public let width: Double
        public let height: Double
        public let states: [String: [[[Double]]]]
    }

    public let source: Source
    public let country: Country
    public let states: [String: MapOutline]

    public static let bundled: BrazilMap? = {
        guard let url = Bundle.module.url(forResource: "brazil-maps", withExtension: "json"),
            let data = try? Data(contentsOf: url)
        else { return nil }
        return try? decode(data)
    }()

    public static func decode(_ data: Data) throws -> BrazilMap {
        try JSONDecoder().decode(BrazilMap.self, from: data)
    }

    public var ufs: [String] {
        states.keys.sorted()
    }

    public func outline(of uf: String) -> MapOutline? {
        states[uf.lowercased()]
    }

    public func countryOutline(_ ufs: Set<String>? = nil) -> MapOutline {
        let selected = country.states.filter { ufs?.contains($0.key) ?? true }
        return MapOutline(
            width: country.width, height: country.height,
            rings: selected.keys.sorted().flatMap { selected[$0] ?? [] })
    }
}

public struct MapShape: Shape {
    private let outline: MapOutline

    public init(_ outline: MapOutline) {
        self.outline = outline
    }

    public func path(in rect: CGRect) -> Path {
        let scale = min(
            rect.width / max(outline.width, .ulpOfOne), rect.height / max(outline.height, .ulpOfOne)
        )
        let origin = CGPoint(
            x: rect.midX - outline.width * scale / 2, y: rect.midY - outline.height * scale / 2)
        var path = Path()
        for ring in outline.rings {
            let points = ring.compactMap { pair -> CGPoint? in
                guard pair.count == 2 else { return nil }
                return CGPoint(x: origin.x + pair[0] * scale, y: origin.y + pair[1] * scale)
            }
            guard let first = points.first else { continue }
            path.move(to: first)
            path.addLines(Array(points.dropFirst()))
            path.closeSubpath()
        }
        return path
    }
}
