import Foundation

public struct VoteSummary: Codable, Hashable, Identifiable, Sendable {
    public struct Tally: Hashable, Sendable {
        public let yes: Int?
        public let no: Int?
        public let others: Int?

        public init(yes: Int?, no: Int?, others: Int?) {
            self.yes = yes
            self.no = no
            self.others = others
        }

        public var total: Int? {
            guard let yes, let no else { return nil }
            return yes + no + (others ?? 0)
        }
    }

    public let id: String
    public let house: House
    public let date: CalendarDay
    public let time: String?
    public let proposition: String
    public let kind: String?
    public let summary: String
    public let plainSummary: String?
    public let themes: [Theme]
    public let result: String?
    public let approved: Bool?
    public let nominal: Bool
    public let yes: Int?
    public let no: Int?
    public let others: Int?

    public init(
        id: String, house: House, date: CalendarDay, time: String?, proposition: String,
        kind: String?, summary: String, plainSummary: String?, themes: [Theme],
        result: String?, approved: Bool?, nominal: Bool, tally: Tally
    ) {
        self.id = id
        self.house = house
        self.date = date
        self.time = time
        self.proposition = proposition
        self.kind = kind
        self.summary = summary
        self.plainSummary = plainSummary
        self.themes = themes
        self.result = result
        self.approved = approved
        self.nominal = nominal
        yes = tally.yes
        no = tally.no
        others = tally.others
    }

    public var tally: Tally { Tally(yes: yes, no: no, others: others) }
}

public struct VoteDetail: Codable, Hashable, Identifiable, Sendable {
    public struct Guidance: Codable, Hashable, Sendable {
        public let party: String
        public let guidance: String

        public init(party: String, guidance: String) {
            self.party = party
            self.guidance = guidance
        }
    }

    public struct PartyTally: Codable, Hashable, Identifiable, Sendable {
        public let party: String
        public let yes: Int
        public let no: Int
        public let others: Int

        public init(party: String, yes: Int, no: Int, others: Int) {
            self.party = party
            self.yes = yes
            self.no = no
            self.others = others
        }

        public var id: String { party }
    }

    public struct Ballot: Codable, Hashable, Identifiable, Sendable {
        public let slug: String?
        public let name: String
        public let party: String
        public let uf: String
        public let vote: String

        public init(slug: String?, name: String, party: String, uf: String, vote: String) {
            self.slug = slug
            self.name = name
            self.party = party
            self.uf = uf
            self.vote = vote
        }

        public var id: String { slug ?? "\(name)-\(party)-\(uf)" }
    }

    private enum CodingKeys: String, CodingKey {
        case quorum, guidance, parties, people, sources
    }

    public let vote: VoteSummary
    public let quorum: Int?
    public let guidance: [Guidance]
    public let parties: [PartyTally]
    public let people: [Ballot]
    public let sources: [Source]

    public init(
        vote: VoteSummary, quorum: Int?, guidance: [Guidance], parties: [PartyTally],
        people: [Ballot], sources: [Source]
    ) {
        self.vote = vote
        self.quorum = quorum
        self.guidance = guidance
        self.parties = parties
        self.people = people
        self.sources = sources
    }

    public init(from decoder: any Decoder) throws {
        vote = try VoteSummary(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        quorum = try container.decodeIfPresent(Int.self, forKey: .quorum)
        guidance = try container.decode([Guidance].self, forKey: .guidance)
        parties = try container.decode([PartyTally].self, forKey: .parties)
        people = try container.decode([Ballot].self, forKey: .people)
        sources = try container.decode([Source].self, forKey: .sources)
    }

    public func encode(to encoder: any Encoder) throws {
        try vote.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(quorum, forKey: .quorum)
        try container.encode(guidance, forKey: .guidance)
        try container.encode(parties, forKey: .parties)
        try container.encode(people, forKey: .people)
        try container.encode(sources, forKey: .sources)
    }

    public var id: String { vote.id }
}
