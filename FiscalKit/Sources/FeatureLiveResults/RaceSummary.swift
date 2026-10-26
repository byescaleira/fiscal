import FiscalDomain
import Foundation

struct RaceSummary: Hashable, Sendable {
    struct Contender: Hashable, Sendable, Identifiable {
        let candidate: RaceCandidate
        let rank: Int
        let percent: String
        let votes: String
        let share: Double
        let dimmed: Bool
        let accessibility: String

        var id: String { candidate.number }
        var slug: String { candidate.portraitSlug }
    }

    struct Ballot: Hashable, Sendable, Identifiable {
        enum Kind: String, CaseIterable, Sendable {
            case valid, blank, null, abstention
        }

        let kind: Kind
        let count: Int
        let share: Double
        let countText: String
        let percentText: String

        var id: String { kind.rawValue }

        var title: String {
            switch kind {
            case .valid: String(appLocalized: "Valid")
            case .blank: String(appLocalized: "Blank")
            case .null: String(appLocalized: "Null")
            case .abstention: String(appLocalized: "Abstention")
            }
        }

        var symbol: String {
            switch kind {
            case .valid: "checkmark.square"
            case .blank: "square"
            case .null: "xmark.square"
            case .abstention: "person.slash"
            }
        }
    }

    static let compactLimit = 4

    let race: Race

    var isDuel: Bool { race.candidates.count <= 2 }

    var hasStarted: Bool { race.hasStarted }

    var title: String { RaceText.title(office: race.office, uf: race.uf) }

    var scope: String { RaceText.scope(race.uf) }

    var office: String { RaceText.office(race.office) }

    var roundText: String { String(appLocalized: "Round \(race.round)") }

    var isDecided: Bool {
        race.final || race.sections.percent >= 100 || race.candidates.contains(where: \.elected)
    }

    var winner: Contender? {
        guard isDecided else { return nil }
        if let elected = contenders.first(where: \.candidate.elected) { return elected }
        return race.round == 2 || isDuel ? contenders.first : nil
    }

    var others: [Contender] {
        Array(contenders.filter { $0.id != winner?.id }.prefix(2))
    }

    var winnerText: String? {
        winner.map { String(appLocalized: "Elected with \($0.percent) of the valid votes") }
    }

    var statusText: String {
        if isDecided { return String(appLocalized: "Final result") }
        return race.hasStarted ? String(appLocalized: "Live") : String(appLocalized: "Today")
    }

    var countedFraction: Double { min(max(race.sections.percent / 100, 0), 1) }

    var countedText: String { RaceText.shortPercent(race.sections.percent) }

    var sectionsText: String {
        RaceText.sections(counted: race.sections.counted, total: race.sections.total)
    }

    var contenders: [Contender] {
        race.candidates.enumerated().map { index, candidate in
            let percent =
                race.hasStarted ? RaceText.percent(candidate.percent) : PublicFormat.missing
            let votes =
                race.hasStarted
                ? String(appLocalized: "\(RaceText.votes(candidate.votes)) votes")
                : PublicFormat.missing
            let base = "\(candidate.name), \(candidate.party), \(percent), \(votes)"
            return Contender(
                candidate: candidate, rank: index + 1, percent: percent, votes: votes,
                share: race.hasStarted ? candidate.percent : 0,
                dimmed: race.final && !candidate.elected,
                accessibility: candidate.elected
                    ? "\(base), \(String(appLocalized: "Elected"))" : base)
        }
    }

    var sides: [Contender] { Array(contenders.prefix(2)) }

    var compactContenders: [Contender] { Array(contenders.prefix(Self.compactLimit)) }

    var hiddenCount: Int { max(race.candidates.count - Self.compactLimit, 0) }

    var hiddenText: String? {
        hiddenCount > 0 ? String(appLocalized: "+\(hiddenCount) more candidates") : nil
    }

    var trailingText: String? {
        guard !isDuel else { return nil }
        let rest = contenders.dropFirst(2)
        guard !rest.isEmpty else { return nil }
        return rest.prefix(2).map { "\($0.candidate.name) \($0.percent)" }.joined(
            separator: " · ")
    }

    var splitShare: Double {
        let first = sides.first?.candidate.percent ?? 0
        let second = sides.dropFirst().first?.candidate.percent ?? 0
        let total = first + second
        return total > 0 ? first / total : 0.5
    }

    var majorityCut: Double? { race.round == 1 && !isDuel ? 50 : nil }

    var majorityText: String? {
        majorityCut == nil
            ? nil
            : String(appLocalized: "Dashed line: half of the valid votes, needed to win in round 1")
    }

    var marginText: String {
        if let elected = race.elected { return RaceText.elected(elected.name) }
        guard race.hasStarted, let first = sides.first, let second = sides.dropFirst().first
        else { return String(appLocalized: "Starts at 5 PM Brasília time") }
        return String(
            appLocalized:
                "Votes apart: \(RaceText.votes(abs(first.candidate.votes - second.candidate.votes)))"
        )
    }

    var sourceText: String {
        guard let date = race.generatedAt else { return String(appLocalized: "Source: TSE") }
        return String(appLocalized: "TSE file from \(RaceText.time(date))")
    }

    var ballotBase: Int { race.votes.total + (race.abstention ?? 0) }

    var ballotTitle: String {
        race.abstention == nil
            ? String(appLocalized: "Votes in the counted polling stations")
            : String(appLocalized: "Voters in the counted polling stations")
    }

    var ballots: [Ballot] {
        let base = ballotBase
        guard race.hasStarted, base > 0 else { return [] }
        var parts: [(Ballot.Kind, Int)] = [
            (.valid, race.votes.valid), (.blank, race.votes.blank), (.null, race.votes.null),
        ]
        if let abstention = race.abstention { parts.append((.abstention, abstention)) }
        return parts.map { kind, count in
            let share = Double(count) / Double(base) * 100
            return Ballot(
                kind: kind, count: count, share: share, countText: RaceText.votes(count),
                percentText: RaceText.shortPercent(share))
        }
    }

    var ballotLine: String {
        let parts = ballots.filter { $0.kind != .valid }
        guard !parts.isEmpty else {
            return String(appLocalized: "Blank and null votes show up with the count")
        }
        return parts.map { "\($0.title) \($0.percentText)" }.joined(separator: " · ")
    }

    var ballotAccessibility: String {
        ballots.map { "\($0.title), \($0.countText), \($0.percentText)" }.joined(separator: "; ")
    }

    var turnoutText: String { RaceText.votes(race.votes.total) }

    var electorateText: String { RaceText.votes(race.electorate) }

    var accessibilityLabel: String {
        ([title, roundText, statusText] + sides.map(\.accessibility) + [marginText, sourceText])
            .joined(separator: ", ")
    }
}
