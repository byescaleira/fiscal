import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct PastRoundBreakdown {
    static let shownBars = 7

    struct Bar: Identifiable, Hashable {
        let id: String
        let label: String
        let party: String?
        let votes: Int
        let share: Double
        let elected: Bool
        let advanced: Bool
        let color: Color
    }

    struct Slice: Identifiable, Hashable {
        let id: String
        let title: String
        let value: Int
        let fraction: Double
        let color: Color
    }

    struct Tile: Identifiable, Hashable {
        let uf: String
        let name: String
        let column: Int
        let row: Int
        let winner: String?
        let share: Double
        let color: Color

        var id: String { uf }

        var code: String { uf.uppercased(with: .app) }
    }

    struct Legend: Identifiable, Hashable {
        let id: String
        let name: String
        let party: String
        let states: Int
        let color: Color
    }

    let race: PastRace
    let round: PastRound

    var isFinalRound: Bool { round.round == race.rounds.last?.round }

    var winners: [PastCandidate] {
        let elected = round.candidates.filter(\.elected)
        if !elected.isEmpty { return elected }
        return round.candidates.filter(\.advanced)
    }

    var leader: PastCandidate? { winners.first ?? round.candidates.first }

    var others: [PastCandidate] {
        let top = Set(winners.map(\.id))
        return Array(round.candidates.filter { !top.contains($0.id) }.prefix(2))
    }

    var title: String {
        race.office == .president
            ? String(appLocalized: "President · \(String(race.year))")
            : "\(MemoryText.office(race.office, seats: race.seats)) · \(race.scopeName) · \(String(race.year))"
    }

    var roundLine: String {
        "\(MemoryText.round(round.round, total: race.rounds.count)) · \(MemoryText.day(round.day))"
    }

    var outcome: String {
        if winners.contains(where: \.elected) {
            return winners.count > 1
                ? String(appLocalized: "ELECTED · 2 SEATS") : String(appLocalized: "ELECTED")
        }
        return winners.isEmpty
            ? String(appLocalized: "MOST VOTED") : String(appLocalized: "WENT TO ROUND 2")
    }

    func color(for party: String, rank: Int) -> Color {
        PartyPalette.of(party: party, fallback: rank).primary
    }

    var bars: [Bar] {
        let shown = Array(round.candidates.prefix(Self.shownBars))
        var out = shown.enumerated().map { index, candidate in
            Bar(
                id: candidate.id, label: MemoryText.name(candidate.ballotName),
                party: candidate.party, votes: candidate.votes, share: candidate.share,
                elected: candidate.elected, advanced: candidate.advanced,
                color: color(for: candidate.party, rank: index))
        }
        let rest = round.candidates.dropFirst(Self.shownBars)
        if !rest.isEmpty {
            let votes = rest.reduce(0) { $0 + $1.votes }
            let share = rest.reduce(0) { $0 + $1.share }
            out.append(
                Bar(
                    id: "others", label: String(appLocalized: "Others (\(rest.count))"),
                    party: nil, votes: votes, share: (share * 100).rounded() / 100,
                    elected: false, advanced: false, color: ChartPalette.other))
        }
        return out
    }

    var annulled: Int {
        round.candidates.compactMap(\.annulled).reduce(0, +)
    }

    var slices: [Slice] {
        guard let electorate = round.electorate, electorate > 0 else { return [] }
        let total = Double(electorate)
        var out: [Slice] = [
            Slice(
                id: "valid", title: String(appLocalized: "Valid votes"), value: round.valid,
                fraction: Double(round.valid) / total, color: ChartPalette.color(at: 0))
        ]
        if let blank = round.blank {
            out.append(
                Slice(
                    id: "blank", title: String(appLocalized: "Blank"), value: blank,
                    fraction: Double(blank) / total, color: ChartPalette.color(at: 5)))
        }
        if let null = round.null {
            out.append(
                Slice(
                    id: "null", title: String(appLocalized: "Null"), value: null,
                    fraction: Double(null) / total, color: ChartPalette.color(at: 2)))
        }
        if let abstentions = round.abstentions {
            out.append(
                Slice(
                    id: "abstention", title: String(appLocalized: "Abstention"),
                    value: abstentions, fraction: Double(abstentions) / total,
                    color: ChartPalette.other))
        }
        return out
    }

    var electorateLine: String? {
        guard let electorate = round.electorate else { return nil }
        return String(appLocalized: "\(RaceText.votes(electorate)) voters registered")
    }

    var turnoutHero: String? {
        guard let electorate = round.electorate, electorate > 0, let turnout = round.turnout else {
            return nil
        }
        return PublicFormat.percent(Double(turnout) / Double(electorate))
    }

    var tiles: [Tile] {
        guard let states = round.states, !states.isEmpty else { return [] }
        let byUF = Dictionary(states.map { ($0.uf, $0) }, uniquingKeysWith: { first, _ in first })
        let parties = Dictionary(
            round.candidates.map { ($0.number, $0.party) }, uniquingKeysWith: { first, _ in first })
        let ranks = Dictionary(
            round.candidates.enumerated().map { ($0.element.number, $0.offset) },
            uniquingKeysWith: { first, _ in first })
        return MemoryTiles.layout.map { place in
            let state = byUF[place.uf]
            let winner = state?.winner
            let color =
                winner.flatMap { number in
                    parties[number].map { color(for: $0, rank: ranks[number] ?? 0) }
                } ?? Color.secondary.opacity(.opacityFill)
            return Tile(
                uf: place.uf, name: RaceText.scope(place.uf), column: place.column,
                row: place.row, winner: winner, share: state?.share ?? 0, color: color)
        }
    }

    var legend: [Legend] {
        let counts = Dictionary(grouping: tiles.compactMap(\.winner), by: { $0 }).mapValues(\.count)
        return round.candidates.enumerated().compactMap { index, candidate in
            guard let states = counts[candidate.number] else { return nil }
            return Legend(
                id: candidate.id, name: MemoryText.name(candidate.ballotName),
                party: candidate.party, states: states,
                color: color(for: candidate.party, rank: index))
        }
    }

    func candidate(number: String?) -> PastCandidate? {
        guard let number else { return nil }
        return round.candidates.first { $0.number == number }
    }

    var sourceLine: String {
        MemoryText.sources(race.sources) ?? String(appLocalized: "Source: TSE open data")
    }
}

enum MemoryTiles {
    static let columns = 6
    static let rows = 7

    static let layout: [(uf: String, column: Int, row: Int)] = [
        ("rr", 2, 0), ("ap", 3, 0),
        ("am", 1, 1), ("pa", 2, 1), ("ma", 3, 1), ("ce", 4, 1), ("rn", 5, 1),
        ("ac", 0, 2), ("ro", 1, 2), ("to", 2, 2), ("pi", 3, 2), ("pe", 4, 2), ("pb", 5, 2),
        ("mt", 1, 3), ("go", 2, 3), ("ba", 3, 3), ("se", 4, 3), ("al", 5, 3),
        ("ms", 1, 4), ("df", 2, 4), ("mg", 3, 4), ("es", 4, 4),
        ("pr", 1, 5), ("sp", 2, 5), ("rj", 3, 5),
        ("rs", 0, 6), ("sc", 1, 6),
    ]
}
