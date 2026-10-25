import Foundation

public struct RaceStanding: Codable, Hashable, Sendable {
    public let number: String
    public let votes: Int
    public let percent: Double
    public let elected: Bool

    public init(number: String, votes: Int, percent: Double, elected: Bool) {
        self.number = number
        self.votes = votes
        self.percent = percent
        self.elected = elected
    }
}

public struct RaceContender: Codable, Hashable, Sendable {
    public let number: String
    public let name: String
    public let party: String

    public init(number: String, name: String, party: String) {
        self.number = number
        self.name = name
        self.party = party
    }
}

public struct RaceActivityState: Codable, Hashable, Sendable {
    public let sectionsPercent: Double
    public let candidates: [RaceStanding]
    public let final: Bool
    public let updatedAt: Double

    public init(sectionsPercent: Double, candidates: [RaceStanding], final: Bool, updatedAt: Double)
    {
        self.sectionsPercent = sectionsPercent
        self.candidates = candidates
        self.final = final
        self.updatedAt = updatedAt
    }

    public init(race: Race, now: Date = .now) {
        self.init(
            sectionsPercent: race.sections.percent,
            candidates: race.candidates.map {
                RaceStanding(
                    number: $0.number, votes: $0.votes, percent: $0.percent, elected: $0.elected)
            },
            final: race.final,
            updatedAt: (race.generatedAt ?? now).timeIntervalSince1970)
    }

    public var updatedDate: Date { Date(timeIntervalSince1970: updatedAt) }

    public func rows(with contenders: [RaceContender]) -> [RaceActivityRow] {
        let names = Dictionary(
            contenders.map { ($0.number, $0) }, uniquingKeysWith: { first, _ in first })
        return candidates.map { standing in
            let contender = names[standing.number]
            return RaceActivityRow(
                number: standing.number, name: contender?.name ?? standing.number,
                party: contender?.party ?? "", votes: standing.votes, percent: standing.percent,
                elected: standing.elected)
        }
    }
}

public struct RaceActivityRow: Hashable, Identifiable, Sendable {
    public let number: String
    public let name: String
    public let party: String
    public let votes: Int
    public let percent: Double
    public let elected: Bool

    public var id: String { number }
}

#if canImport(ActivityKit) && os(iOS)
    import ActivityKit

    public struct RaceActivityAttributes: ActivityAttributes {
        public typealias ContentState = RaceActivityState

        public let raceId: String
        public let office: Race.Office
        public let uf: String
        public let candidates: [RaceContender]

        public init(raceId: String, office: Race.Office, uf: String, candidates: [RaceContender]) {
            self.raceId = raceId
            self.office = office
            self.uf = uf
            self.candidates = candidates
        }

        public init(race: Race) {
            self.init(
                raceId: race.id, office: race.office, uf: race.uf,
                candidates: race.candidates.map {
                    RaceContender(number: $0.number, name: $0.name, party: $0.party)
                })
        }
    }
#endif
