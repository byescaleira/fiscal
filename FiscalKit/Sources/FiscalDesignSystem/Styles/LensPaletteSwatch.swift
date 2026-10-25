import SwiftUI

public enum LensPaletteSwatch: String, CaseIterable, Identifiable, Sendable {
    case forest, annatto, indigo, ipe, savanna, sea, graphite, sand

    public var id: String { rawValue }

    public static var leading: [LensPaletteSwatch] { [.forest, .indigo, .savanna, .graphite] }

    public static func named(_ id: String?) -> LensPaletteSwatch? {
        id.flatMap(LensPaletteSwatch.init(rawValue:))
    }

    public var mirror: LensPaletteSwatch {
        switch self {
        case .forest: .annatto
        case .annatto: .forest
        case .indigo: .ipe
        case .ipe: .indigo
        case .savanna: .sea
        case .sea: .savanna
        case .graphite: .sand
        case .sand: .graphite
        }
    }

    public var accent: Color {
        Color(light: hexes.light, dark: hexes.dark)
    }

    public var shareColors: [Color] {
        [
            Color(light: hexes.light, dark: hexes.light),
            Color(light: hexes.share, dark: hexes.share),
        ]
    }

    public var gradient: LinearGradient {
        LinearGradient(colors: shareColors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var hexes: (light: UInt32, dark: UInt32, share: UInt32) {
        switch self {
        case .forest: (0x1F7A4D, 0x4FBF86, 0xE9B824)
        case .annatto: (0xB3362B, 0xE8675A, 0xF2994A)
        case .indigo: (0x2D5DA8, 0x6E9BE6, 0x8EC5F0)
        case .ipe: (0xA8327A, 0xE070B2, 0xF2A7C8)
        case .savanna: (0x9A5F0E, 0xE0A04A, 0xE9CF8C)
        case .sea: (0x1F6F78, 0x5BB5BE, 0x9ED8D8)
        case .graphite: (0x4A5563, 0xA3AEBD, 0xC9CFD6)
        case .sand: (0x8A6A4A, 0xC9A57E, 0xE6D5BC)
        }
    }
}
