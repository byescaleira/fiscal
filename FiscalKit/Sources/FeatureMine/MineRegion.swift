import FeatureCore
import FiscalDomain
import Foundation

public struct MineSeat: Identifiable, Hashable, Sendable {
    public enum Level: String, Hashable, Sendable {
        case city, state, country
    }

    public let level: Level
    public let place: String
    public let holder: PersonCard
    public let vice: PersonCard?
    public let elected: [PersonCard]

    public var id: Level { level }

    public var title: String {
        switch level {
        case .city: String(appLocalized: "City Hall")
        case .state: String(appLocalized: "State Government")
        case .country: String(appLocalized: "Federal Government")
        }
    }

    public var kicker: String { "\(title) · \(place)".uppercased(with: .app) }

    public var slugs: [String] {
        [holder.slug] + [vice?.slug].compactMap(\.self) + elected.map(\.slug)
    }
}

public struct MineBench: Identifiable, Hashable, Sendable {
    public struct PartyShare: Identifiable, Hashable, Sendable {
        public let party: String
        public let count: Int
        public let start: Int

        public var id: String { party }

        public var end: Int { start + count }
    }

    public static let faceLimit = 8
    public static let leadingLimit = 3

    public let office: Office
    public let title: String
    public let subtitle: String
    public let members: [PersonCard]
    public let elected: [PersonCard]
    public let parties: [PartyShare]

    public init(
        office: Office, title: String, subtitle: String, members: [PersonCard],
        elected: [PersonCard]
    ) {
        self.office = office
        self.title = title
        self.subtitle = subtitle
        self.members = members
        self.elected = elected
        parties = Self.shares(members)
    }

    public var id: Office { office }

    public var total: Int { members.count }

    public var leading: [PartyShare] { Array(parties.prefix(Self.leadingLimit)) }

    public var faces: [PersonCard] { Array(members.prefix(Self.faceLimit)) }

    public var hiddenFaces: Int { max(total - Self.faceLimit, 0) }

    public func share(of party: PartyShare) -> String {
        guard total > 0 else { return PublicFormat.missing }
        return (Double(party.count) / Double(total))
            .formatted(.percent.precision(.fractionLength(0)).locale(.app))
    }

    public func party(at position: Int) -> PartyShare? {
        parties.first { position >= $0.start && position < $0.end }
    }

    public var compositionText: String {
        parties.map { "\($0.party) \(PublicFormat.number($0.count))" }.joined(separator: ", ")
    }

    static func shares(_ people: [PersonCard]) -> [PartyShare] {
        let counts = Dictionary(grouping: people, by: \.party).mapValues(\.count)
        let ordered = counts.sorted { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value > rhs.value }
            return lhs.key.localizedStandardCompare(rhs.key) == .orderedAscending
        }
        var start = 0
        return ordered.map { party, count in
            defer { start += count }
            return PartyShare(party: party, count: count, start: start)
        }
    }
}

public struct MineRoster: Hashable, Sendable {
    public let title: String
    public let people: [PersonCard]
    public let parties: [MineBench.PartyShare]

    public init(title: String, people: [PersonCard]) {
        self.title = title
        self.people = people
        parties = MineBench.shares(people)
    }

    public func filtered(query: String, party: String?) -> [PersonCard] {
        let term = MineModel.normalized(query)
        return people.filter { card in
            (party == nil || card.party == party)
                && (term.isEmpty || MineModel.normalized(card.name).contains(term))
        }
    }
}

public struct MineVote: Identifiable, Hashable, Sendable {
    public let vote: VoteSummary
    public let counts: [BallotChoice: Int]

    public var id: String { vote.id }

    public init?(detail: VoteDetail, uf: String, seats: Int) {
        let uf = uf.lowercased()
        let ballots = detail.people.filter { $0.uf.lowercased() == uf }
        guard !ballots.isEmpty else { return nil }
        var counts: [BallotChoice: Int] = [:]
        for ballot in ballots {
            counts[BallotChoice(vote: ballot.vote) ?? .absent, default: 0] += 1
        }
        let missing = seats - ballots.count
        if missing > 0 { counts[.absent, default: 0] += missing }
        vote = detail.vote
        self.counts = counts
    }

    public func count(_ choice: BallotChoice) -> Int { counts[choice] ?? 0 }

    public var board: VoteBoard { VoteBoard(vote) }

    public var heading: String {
        switch vote.house {
        case .camara: String(appLocalized: "How your deputies voted")
        case .senado: String(appLocalized: "How your senators voted")
        }
    }

    public var countsText: String {
        BallotChoice.allCases.compactMap { choice -> String? in
            let value = count(choice)
            guard value > 0 else { return nil }
            return "\(PublicFormat.number(value)) \(Self.label(choice, count: value))"
        }
        .joined(separator: " · ")
    }

    static func label(_ choice: BallotChoice, count: Int) -> String {
        switch choice {
        case .yes, .no: choice.title
        case .abstain:
            count == 1
                ? String(appLocalized: "abstention") : String(appLocalized: "abstentions")
        case .absent:
            count == 1 ? String(appLocalized: "absent") : String(appLocalized: "absent (plural)")
        }
    }
}

public struct MineActivity: Hashable, Sendable {
    public var highlights: [Highlight] = []
    public var highlightsAreNational = false
    public var method: WeightMethod?
    public var votes: [MineVote] = []
    public var actions: [String: ActionItem] = [:]
    public var mandates: [String: Profile.Mandate] = [:]
    public var sources: [Source] = []

    public init() {}

    public static let empty = MineActivity()

    public var isEmpty: Bool { highlights.isEmpty && votes.isEmpty }
}

public enum MineRelevance: Sendable {
    case high, medium, low

    public init(weight: Int) {
        self = weight >= 70 ? .high : weight >= 40 ? .medium : .low
    }

    public var title: String {
        switch self {
        case .high: String(appLocalized: "High relevance")
        case .medium: String(appLocalized: "Medium relevance")
        case .low: String(appLocalized: "Low relevance")
        }
    }
}
