import Foundation

public struct HemicycleLayout: Equatable, Sendable {
    public enum Group: Int, CaseIterable, Sendable {
        case yes, no, other, absent
    }

    public struct Seat: Equatable, Sendable {
        public let row: Int
        public let angle: Double
        public let group: Group
        public let rank: Int
    }

    public static let inner = 0.38
    static let maximumRows = 24

    public let seatsPerRow: [Int]
    public let seats: [Seat]
    public let lastRank: Int

    public init(yes: Int, no: Int, others: Int, seats total: Int) {
        let yes = max(yes, .zero)
        let no = max(no, .zero)
        let other = max(others, .zero)
        let absent = max(total - yes - no - other, .zero)
        let count = yes + no + other + absent
        let rows = Self.rowCount(for: count)
        let perRow = Self.seatsPerRow(count, rows: rows)
        var spots: [(row: Int, angle: Double)] = []
        for (row, seats) in perRow.enumerated() {
            let spacing = Double.pi / Double(seats)
            for seat in 0..<seats {
                spots.append((row: row, angle: Double.pi - (Double(seat) + 0.5) * spacing))
            }
        }
        let ordered = spots.sorted { lhs, rhs in
            lhs.angle == rhs.angle ? lhs.row < rhs.row : lhs.angle > rhs.angle
        }
        let lead = max(yes, no)
        var placed: [Seat] = []
        for (order, spot) in ordered.enumerated() {
            let group: Group
            let rank: Int
            if order < yes {
                group = .yes
                rank = order
            } else if order >= count - no {
                group = .no
                rank = count - 1 - order
            } else if order < yes + absent {
                group = .absent
                rank = lead + order - yes
            } else {
                group = .other
                rank = lead + order - yes
            }
            placed.append(Seat(row: spot.row, angle: spot.angle, group: group, rank: rank))
        }
        seatsPerRow = perRow
        seats = placed
        lastRank = placed.map(\.rank).max() ?? .zero
    }

    public var count: Int { seats.count }

    public func count(of group: Group) -> Int { seats.filter { $0.group == group }.count }

    public func angle(beforeSeat order: Int) -> Double {
        let sorted = seats.map(\.angle).sorted(by: >)
        guard order > .zero, order < sorted.count else { return order <= .zero ? .pi : .zero }
        return (sorted[order - 1] + sorted[order]) / 2
    }

    static func rowCount(for seats: Int) -> Int {
        guard seats > .zero else { return 1 }
        let candidates = 1...maximumRows
        return candidates.min { lhs, rhs in
            mismatch(rows: lhs, seats: seats) < mismatch(rows: rhs, seats: seats)
        } ?? 1
    }

    static func seatsPerRow(_ seats: Int, rows: Int) -> [Int] {
        let width = (1 - inner) / Double(rows)
        let radii = (0..<rows).map { inner + (Double($0) + 0.5) * width }
        let total = radii.reduce(0, +)
        let shares = radii.map { Double(seats) * $0 / total }
        var counts = shares.map { Int($0.rounded(.down)) }
        let missing = seats - counts.reduce(0, +)
        let byRemainder = shares.indices.sorted {
            shares[$0] - shares[$0].rounded(.down) > shares[$1] - shares[$1].rounded(.down)
        }
        for index in byRemainder.prefix(missing) { counts[index] += 1 }
        return counts
    }

    private static func mismatch(rows: Int, seats: Int) -> Double {
        let width = (1 - inner) / Double(rows)
        let arc = Double.pi * Double(rows) * (1 + inner) / 2
        return abs(arc / Double(seats) - width)
    }
}
