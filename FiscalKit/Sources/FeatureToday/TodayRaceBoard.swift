import FiscalDomain
import Foundation

public struct TodayRaceBoard: Hashable, Sendable {
    public struct Side: Hashable, Sendable, Identifiable {
        public let candidate: RaceCandidate
        public let index: Int
        public let percent: String
        public let slug: String
        public let dimmed: Bool
        public let accessibility: String

        public var id: String { candidate.number }
    }

    public let race: Race
    public let others: Int
    public let isStale: Bool

    public init(race: Race, others: Int = 0, isStale: Bool = false) {
        self.race = race
        self.others = others
        self.isStale = isStale
    }

    public static let winnerWindow: TimeInterval = 24 * 60 * 60

    public static func featured(in races: [Race], now: Date = .now) -> Race? {
        let live = races.filter { !$0.final }
        if let race = live.first(where: { $0.office == .president }) ?? live.first { return race }
        return races.first { race in
            guard race.office == .president, race.final,
                let date = try? Date(race.sourceGeneratedAt, strategy: .iso8601)
            else { return false }
            return now.timeIntervalSince(date) < winnerWindow
        }
    }

    public var sides: [Side] {
        race.candidates.prefix(2).enumerated().map { index, candidate in
            let percent =
                race.hasStarted ? RaceText.percent(candidate.percent) : PublicFormat.missing
            let votes =
                race.hasStarted
                ? String(appLocalized: "\(RaceText.votes(candidate.votes)) votes")
                : PublicFormat.missing
            let base = "\(candidate.name), \(candidate.party), \(percent), \(votes)"
            return Side(
                candidate: candidate, index: index, percent: percent,
                slug: Self.slug(candidate.name), dimmed: race.final && !candidate.elected,
                accessibility: candidate.elected
                    ? "\(base), \(String(appLocalized: "Elected"))" : base)
        }
    }

    public var title: String { RaceText.title(office: race.office, uf: race.uf) }

    public var roundText: String { String(appLocalized: "Round \(race.round)") }

    public var countedFraction: Double { min(max(race.sections.percent / 100, 0), 1) }

    public var centerValue: String {
        race.final ? String(appLocalized: "Final") : RaceText.shortPercent(race.sections.percent)
    }

    public var centerCaption: String {
        race.final ? String(appLocalized: "TSE") : String(appLocalized: "counted")
    }

    public var statusText: String {
        if race.final { return String(appLocalized: "Final result") }
        return race.hasStarted ? String(appLocalized: "Live") : String(appLocalized: "Today")
    }

    public var marginText: String {
        if let elected = race.elected { return RaceText.elected(elected.name) }
        let sides = race.candidates.prefix(2)
        guard race.hasStarted, let first = sides.first, let second = sides.dropFirst().first
        else { return String(appLocalized: "Starts at 5 PM Brasília time") }
        return String(
            appLocalized: "Votes apart: \(RaceText.votes(abs(first.votes - second.votes)))")
    }

    public var sourceText: String {
        guard let date = race.generatedAt else { return String(appLocalized: "Source: TSE") }
        let time = RaceText.time(date)
        return isStale
            ? String(appLocalized: "No update since \(time) · TSE")
            : String(appLocalized: "TSE file from \(time)")
    }

    public var othersText: String? {
        others > 0 ? String(appLocalized: "Other races today: \(others)") : nil
    }

    public var accessibilityLabel: String {
        ([title, roundText, statusText] + sides.map(\.accessibility) + [marginText, sourceText])
            .joined(separator: ", ")
    }

    public static func slug(_ name: String) -> String {
        name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .joined(separator: "-")
    }
}
