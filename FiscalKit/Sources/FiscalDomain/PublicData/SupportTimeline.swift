import Foundation

public struct SupportBallot: Hashable, Identifiable, Sendable {
    public let person: PersonCard
    public let vote: String

    public init(person: PersonCard, vote: String) {
        self.person = person
        self.vote = vote
    }

    public var id: String { person.slug }
}

public struct SupportEvent: Hashable, Identifiable, Sendable {
    public enum Kind: String, Hashable, Sendable {
        case vote, proposal, speech, highlight
    }

    public let id: String
    public let kind: Kind
    public let date: CalendarDay
    public let title: String
    public let reference: String?
    public let ballots: [SupportBallot]
    public let people: [PersonCard]
    public let themes: [Theme]
    public let voteID: String?
    public let content: ContentDetail?

    public init(
        id: String, kind: Kind, date: CalendarDay, title: String, reference: String? = nil,
        ballots: [SupportBallot] = [], people: [PersonCard] = [], themes: [Theme] = [],
        voteID: String? = nil, content: ContentDetail? = nil
    ) {
        self.id = id
        self.kind = kind
        self.date = date
        self.title = title
        self.reference = reference
        self.ballots = ballots
        self.people = people
        self.themes = themes
        self.voteID = voteID
        self.content = content
    }

    public func involves(_ slug: String) -> Bool {
        people.contains { $0.slug == slug } || ballots.contains { $0.person.slug == slug }
    }
}

public enum SupportFilter: Hashable, Sendable {
    case all
    case person(String)
    case cause(Theme)
}

public struct SupportSources: Sendable {
    public let cards: [PersonCard]
    public let actions: [String: ActionList]
    public let votes: [String: [PersonVote]]
    public let recent: [VoteSummary]
    public let highlights: HighlightList?
    public let method: WeightMethod?

    public init(
        cards: [PersonCard] = [], actions: [String: ActionList] = [:],
        votes: [String: [PersonVote]] = [:], recent: [VoteSummary] = [],
        highlights: HighlightList? = nil, method: WeightMethod? = nil
    ) {
        self.cards = cards
        self.actions = actions
        self.votes = votes
        self.recent = recent
        self.highlights = highlights
        self.method = method
    }
}

public enum SupportTimeline {
    public static let limit = 100

    public static func build(_ choice: SupportChoice, from sources: SupportSources)
        -> [SupportEvent]
    {
        var builder = Builder(choice: choice, method: sources.method)
        for card in sources.cards where choice.supports(card.slug) {
            for vote in sources.votes[card.slug] ?? [] { builder.add(vote, by: card) }
            if let list = sources.actions[card.slug] { builder.add(list, by: card) }
        }
        for vote in sources.recent where matches(vote.themes, choice) { builder.add(vote) }
        if let list = sources.highlights {
            for item in list.items where matches(item.themes ?? [], choice) {
                builder.add(item, method: list.method ?? sources.method)
            }
        }
        return Array(builder.events.prefix(limit))
    }

    public static func filtered(_ events: [SupportEvent], by filter: SupportFilter)
        -> [SupportEvent]
    {
        switch filter {
        case .all: events
        case .person(let slug): events.filter { $0.involves(slug) }
        case .cause(let cause): events.filter { $0.themes.contains(cause) }
        }
    }

    private static func matches(_ themes: [Theme], _ choice: SupportChoice) -> Bool {
        themes.contains(where: choice.contains)
    }

    private struct Builder {
        let choice: SupportChoice
        let method: WeightMethod?
        private var found: [String: SupportEvent] = [:]

        init(choice: SupportChoice, method: WeightMethod?) {
            self.choice = choice
            self.method = method
        }

        var events: [SupportEvent] {
            found.values.sorted { lhs, rhs in
                lhs.date == rhs.date ? lhs.id < rhs.id : lhs.date > rhs.date
            }
        }

        mutating func add(_ vote: PersonVote, by card: PersonCard) {
            merge(
                SupportEvent(
                    id: Self.voteKey(vote.voteId), kind: .vote, date: vote.date,
                    title: vote.summary, reference: vote.proposition,
                    ballots: [SupportBallot(person: card, vote: vote.vote)],
                    themes: vote.themes, voteID: vote.voteId))
        }

        mutating func add(_ list: ActionList, by card: PersonCard) {
            for item in list.items {
                if item.kind == .vote, let ref = item.ref {
                    merge(
                        SupportEvent(
                            id: Self.voteKey(ref), kind: .vote, date: item.date, title: item.title,
                            reference: item.proposition,
                            ballots: item.ballot.map { [SupportBallot(person: card, vote: $0)] }
                                ?? [],
                            people: item.ballot == nil ? [card] : [], themes: item.themes,
                            voteID: ref))
                } else {
                    let content = ContentDetail(
                        action: item, person: card, method: method, sourceLine: nil)
                    merge(
                        SupportEvent(
                            id: Self.actionKey(item.id),
                            kind: item.kind == .speech ? .speech : .proposal, date: item.date,
                            title: item.title, reference: item.proposition, people: [card],
                            themes: item.themes, content: content))
                }
            }
        }

        mutating func add(_ vote: VoteSummary) {
            merge(
                SupportEvent(
                    id: Self.voteKey(vote.id), kind: .vote, date: vote.date,
                    title: vote.plainSummary ?? vote.summary, reference: vote.proposition,
                    themes: vote.themes, voteID: vote.id))
        }

        mutating func add(_ item: Highlight, method: WeightMethod?) {
            if item.kind == .vote {
                merge(
                    SupportEvent(
                        id: Self.voteKey(item.route), kind: .vote, date: item.date,
                        title: item.plainSummary ?? item.title, reference: item.proposition,
                        themes: item.themes ?? [], voteID: item.route))
                return
            }
            let content = ContentDetail(highlight: item, method: method, sourceLine: nil)
            let id =
                item.id.hasPrefix("action-")
                ? Self.actionKey(String(item.id.dropFirst("action-".count))) : item.id
            merge(
                SupportEvent(
                    id: id, kind: item.kind == .action ? .proposal : .highlight, date: item.date,
                    title: content.title, reference: item.proposition,
                    people: item.person.map { [$0] } ?? [], themes: item.themes ?? [],
                    content: content))
        }

        private mutating func merge(_ event: SupportEvent) {
            guard let current = found[event.id] else {
                found[event.id] = event
                return
            }
            let ballots = Self.unique(current.ballots + event.ballots) { $0.person.slug }
                .sorted { choice.rank(of: $0.person.slug) < choice.rank(of: $1.person.slug) }
            let voters = Set(ballots.map(\.person.slug))
            let people = Self.unique(current.people + event.people) { $0.slug }
                .filter { !voters.contains($0.slug) }
            found[event.id] = SupportEvent(
                id: current.id, kind: current.kind, date: max(current.date, event.date),
                title: event.ballots.isEmpty && event.people.isEmpty ? event.title : current.title,
                reference: current.reference ?? event.reference, ballots: ballots, people: people,
                themes: Self.unique(current.themes + event.themes) { $0.rawValue },
                voteID: current.voteID ?? event.voteID, content: current.content ?? event.content)
        }

        private static func voteKey(_ id: String) -> String { "vote-\(id)" }

        private static func actionKey(_ id: String) -> String { "action-\(id)" }

        private static func unique<Value, Key: Hashable>(
            _ values: [Value], by key: (Value) -> Key
        ) -> [Value] {
            var seen: Set<Key> = []
            return values.filter { seen.insert(key($0)).inserted }
        }
    }
}

extension Office {
    public var publishesVotes: Bool {
        self == .senator || self == .federalDeputy || self == .stateDeputy
    }
}
