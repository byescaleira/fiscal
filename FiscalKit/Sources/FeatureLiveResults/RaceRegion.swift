import FiscalDomain
import Foundation

public enum RaceRegion: String, CaseIterable, Identifiable, Sendable {
    case north, northeast, centerWest, southeast, south

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .north: String(appLocalized: "North")
        case .northeast: String(appLocalized: "Northeast")
        case .centerWest: String(appLocalized: "Center-West")
        case .southeast: String(appLocalized: "Southeast")
        case .south: String(appLocalized: "South")
        }
    }

    public var symbol: String {
        switch self {
        case .north: "tree"
        case .northeast: "sun.max"
        case .centerWest: "leaf"
        case .southeast: "building.2"
        case .south: "snowflake"
        }
    }

    public static func of(uf: String) -> RaceRegion? {
        switch uf.lowercased() {
        case "ac", "am", "ap", "pa", "ro", "rr", "to": .north
        case "al", "ba", "ce", "ma", "pb", "pe", "pi", "rn", "se": .northeast
        case "df", "go", "ms", "mt": .centerWest
        case "es", "mg", "rj", "sp": .southeast
        case "pr", "rs", "sc": .south
        default: nil
        }
    }
}

public enum RaceStatusFilter: String, CaseIterable, Identifiable, Sendable {
    case all, counting, decided

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .all: String(appLocalized: "All Races")
        case .counting: String(appLocalized: "Still Counting")
        case .decided: String(appLocalized: "Decided")
        }
    }

    public var symbol: String {
        switch self {
        case .all: "square.grid.2x2"
        case .counting: "dot.radiowaves.left.and.right"
        case .decided: "checkmark.seal"
        }
    }

    func includes(_ race: Race) -> Bool {
        switch self {
        case .all: true
        case .counting: !race.final
        case .decided: race.final
        }
    }
}

public struct RaceGroup: Identifiable, Sendable {
    public let region: RaceRegion?
    public let races: [Race]

    public var id: String { region?.rawValue ?? "other" }

    public var title: String {
        region?.title ?? String(appLocalized: "Other Races")
    }
}
