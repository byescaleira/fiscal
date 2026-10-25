import FiscalDomain
import Foundation

public struct StateTile: Identifiable, Equatable, Sendable {
    public let uf: String
    public let title: String
    public let column: Int
    public let row: Int
    public let cents: Int?
    public let share: Double
    public let intensity: Double

    public var id: String { uf }
    public var code: String { uf.uppercased(with: .app) }
    public var value: String { PublicFormat.compactMoney(cents: cents) }
    public var percent: String { cents == nil ? PublicFormat.missing : PublicFormat.percent(share) }

    public static let columns = 6
    public static let rows = 7

    private static let layout: [(uf: String, column: Int, row: Int)] = [
        ("rr", 2, 0), ("ap", 3, 0),
        ("am", 1, 1), ("pa", 2, 1), ("ma", 3, 1), ("ce", 4, 1), ("rn", 5, 1),
        ("ac", 0, 2), ("ro", 1, 2), ("to", 2, 2), ("pi", 3, 2), ("pe", 4, 2), ("pb", 5, 2),
        ("mt", 1, 3), ("go", 2, 3), ("ba", 3, 3), ("se", 4, 3), ("al", 5, 3),
        ("ms", 1, 4), ("df", 2, 4), ("mg", 3, 4), ("es", 4, 4),
        ("pr", 1, 5), ("sp", 2, 5), ("rj", 3, 5),
        ("rs", 0, 6), ("sc", 1, 6),
    ]

    public static func tiles(_ states: [MoneyOverview.StateAmount]) -> [StateTile] {
        let byState = Dictionary(
            states.map { ($0.uf.lowercased(), $0.cents) }, uniquingKeysWith: +)
        let total = byState.values.reduce(0, +)
        let peak = byState.values.max() ?? 0
        return layout.map { place in
            let cents = byState[place.uf]
            let share = total > 0 ? Double(cents ?? 0) / Double(total) : 0
            let intensity = peak > 0 ? (Double(cents ?? 0) / Double(peak)).squareRoot() : 0
            return StateTile(
                uf: place.uf, title: RaceText.scope(place.uf), column: place.column,
                row: place.row, cents: cents, share: share, intensity: intensity)
        }
    }
}

public struct YearPoint: Identifiable, Equatable, Sendable {
    public let year: Int
    public let cents: Int
    public let isCurrent: Bool

    public var id: Int { year }
    public var reais: Double { Double(cents) / 100 }
    public var value: String { PublicFormat.compactMoney(cents: cents) }
    public var fullValue: String { PublicFormat.money(cents: cents) }
}

public struct ReceiptPoint: Identifiable, Equatable, Sendable {
    public let id: String
    public let supplier: String
    public let category: String
    public let cents: Int
    public let lane: Int

    public var reais: Double { Double(cents) / 100 }
    public var value: String { PublicFormat.money(cents: cents) }

    public static func lane(for id: String, lanes: Int) -> Int {
        let seed = id.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
        return seed % max(lanes, 1)
    }
}
