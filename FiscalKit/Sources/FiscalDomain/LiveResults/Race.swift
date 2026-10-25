import Foundation

public struct Race: Codable, Hashable, Identifiable, Sendable {
    public enum Office: String, Codable, Hashable, Sendable {
        case president, governor
    }

    public struct Sections: Codable, Hashable, Sendable {
        public let total: Int
        public let counted: Int
        public let percent: Double

        public init(total: Int, counted: Int, percent: Double) {
            self.total = total
            self.counted = counted
            self.percent = percent
        }
    }

    public struct Votes: Codable, Hashable, Sendable {
        public let valid: Int
        public let blank: Int
        public let null: Int
        public let total: Int

        public init(valid: Int, blank: Int, null: Int, total: Int) {
            self.valid = valid
            self.blank = blank
            self.null = null
            self.total = total
        }
    }

    public let id: String
    public let office: Office
    public let uf: String
    public let round: Int
    public let sections: Sections
    public let electorate: Int
    public let turnout: Int
    public let votes: Votes
    public let candidates: [RaceCandidate]
    public let final: Bool
    public let sourceGeneratedAt: String

    public init(
        id: String, office: Office, uf: String, round: Int, sections: Sections, electorate: Int,
        turnout: Int, votes: Votes, candidates: [RaceCandidate], final: Bool,
        sourceGeneratedAt: String
    ) {
        self.id = id
        self.office = office
        self.uf = uf
        self.round = round
        self.sections = sections
        self.electorate = electorate
        self.turnout = turnout
        self.votes = votes
        self.candidates = candidates
        self.final = final
        self.sourceGeneratedAt = sourceGeneratedAt
    }

    public var elected: RaceCandidate? { candidates.first(where: \.elected) }

    public var leader: RaceCandidate? {
        guard let first = candidates.first, first.votes > 0 else { return nil }
        return first
    }

    public var hasStarted: Bool { sections.counted > 0 }

    public var generatedAt: Date? {
        try? Date(sourceGeneratedAt, strategy: .iso8601)
    }
}

public struct RaceCandidate: Codable, Hashable, Identifiable, Sendable {
    public let number: String
    public let name: String
    public let party: String
    public let votes: Int
    public let percent: Double
    public let elected: Bool

    public var id: String { number }

    public init(
        number: String, name: String, party: String, votes: Int, percent: Double, elected: Bool
    ) {
        self.number = number
        self.name = name
        self.party = party
        self.votes = votes
        self.percent = percent
        self.elected = elected
    }
}

public struct RaceList: Codable, Sendable {
    public let races: [Race]
    public let fetchedAt: String

    public init(races: [Race], fetchedAt: String) {
        self.races = races
        self.fetchedAt = fetchedAt
    }
}
