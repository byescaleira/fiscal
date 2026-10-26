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

    public struct Related: Codable, Hashable, Identifiable, Sendable {
        public let id: String
        public let time: String?
        public let summary: String
        public let nominal: Bool
        public let approved: Bool?

        public init(id: String, time: String?, summary: String, nominal: Bool, approved: Bool?) {
            self.id = id
            self.time = time
            self.summary = summary
            self.nominal = nominal
            self.approved = approved
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
    public let turn: Int?
    public let group: String?
    public let relatedCount: Int?
    public let related: [Related]?

    public init(
        id: String, house: House, date: CalendarDay, time: String?, proposition: String,
        kind: String?, summary: String, plainSummary: String?, themes: [Theme],
        result: String?, approved: Bool?, nominal: Bool, tally: Tally,
        group: String? = nil, related: [Related] = [], relatedCount: Int? = nil, turn: Int? = nil
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
        self.turn = turn
        self.group = group
        self.related = related.isEmpty ? nil : related
        self.relatedCount = relatedCount ?? (related.isEmpty ? nil : related.count)
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        house = try c.decode(House.self, forKey: .house)
        date = try c.decode(CalendarDay.self, forKey: .date)
        time = try c.decodeIfPresent(String.self, forKey: .time)
        proposition = try c.decodeIfPresent(String.self, forKey: .proposition) ?? ""
        kind = try c.decodeIfPresent(String.self, forKey: .kind)
        summary = try c.decode(String.self, forKey: .summary)
        plainSummary = try c.decodeIfPresent(String.self, forKey: .plainSummary)
        themes = try c.decode([Theme].self, forKey: .themes)
        result = try c.decodeIfPresent(String.self, forKey: .result)
        approved = try c.decodeIfPresent(Bool.self, forKey: .approved)
        nominal = try c.decode(Bool.self, forKey: .nominal)
        yes = try c.decodeIfPresent(Int.self, forKey: .yes)
        no = try c.decodeIfPresent(Int.self, forKey: .no)
        others = try c.decodeIfPresent(Int.self, forKey: .others)
        turn = try c.decodeIfPresent(Int.self, forKey: .turn)
        group = try c.decodeIfPresent(String.self, forKey: .group)
        relatedCount = try c.decodeIfPresent(Int.self, forKey: .relatedCount)
        related = try c.decodeIfPresent([Related].self, forKey: .related)
    }

    public var tally: Tally { Tally(yes: yes, no: no, others: others) }

    public var heading: String { VoteHeading.text(proposition, turn: turn) }

    public var sameDayVotes: [Related] { related ?? [] }

    public var sameDayCount: Int { max(relatedCount ?? 0, sameDayVotes.count) }
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
    public let quorum: String?
    public let guidance: [Guidance]
    public let parties: [PartyTally]
    public let people: [Ballot]
    public let sources: [Source]

    public init(
        vote: VoteSummary, quorum: String?, guidance: [Guidance], parties: [PartyTally],
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
        quorum = try container.decodeIfPresent(String.self, forKey: .quorum)
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

public enum VoteHeading {
    public static func text(_ proposition: String, turn: Int?) -> String {
        guard let turn, turn > 0 else { return proposition }
        let label = String(appLocalized: "Turn \(turn)")
        return proposition.isEmpty ? label : "\(proposition) · \(label)"
    }
}
