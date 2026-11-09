import Foundation

public enum FeedReason: Hashable, Sendable {
    case following
    case region(String)
    case relevant

    fileprivate var rank: Int {
        switch self {
        case .following: 0
        case .region: 1
        case .relevant: 2
        }
    }
}

public enum FeedFilter: String, CaseIterable, Hashable, Identifiable, Sendable {
    case all, following, relevant

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .all: String(appLocalized: "All")
        case .following: String(appLocalized: "Following")
        case .relevant: String(appLocalized: "Relevant")
        }
    }
}

public struct FeedExpenses: Hashable, Sendable {
    public let slug: String
    public let year: Int
    public let month: Int
    public let cents: Int

    public init(slug: String, year: Int, month: Int, cents: Int) {
        self.slug = slug
        self.year = year
        self.month = month
        self.cents = cents
    }
}

public struct FeedItem: Hashable, Identifiable, Sendable {
    public enum Kind: String, Hashable, Sendable {
        case vote, proposal, speech, expenses, check, event, highlight
    }

    public let id: String
    public let kind: Kind
    public let date: CalendarDay
    public let title: String
    public let detail: String?
    public let reference: String?
    public let ballots: [SupportBallot]
    public let people: [PersonCard]
    public let reason: FeedReason
    public let themes: [Theme]
    public let voteID: String?
    public let expenses: FeedExpenses?
    public let content: ContentDetail?
    public let url: URL?

    public init(
        id: String, kind: Kind, date: CalendarDay, title: String, detail: String? = nil,
        reference: String? = nil, ballots: [SupportBallot] = [], people: [PersonCard] = [],
        reason: FeedReason, themes: [Theme] = [], voteID: String? = nil,
        expenses: FeedExpenses? = nil, content: ContentDetail? = nil, url: URL? = nil
    ) {
        self.id = id
        self.kind = kind
        self.date = date
        self.title = title
        self.detail = detail
        self.reference = reference
        self.ballots = ballots
        self.people = people
        self.reason = reason
        self.themes = themes
        self.voteID = voteID
        self.expenses = expenses
        self.content = content
        self.url = url
    }

    public var isFollowing: Bool { reason == .following }

    public var involved: [PersonCard] { ballots.map(\.person) + people }
}

public struct FeedSources: Sendable {
    public let following: [PersonCard]
    public let activities: [FollowingFeed.Activity]
    public let actions: [String: ActionList]
    public let speeches: [String: [Speech]]
    public let recent: [VoteSummary]
    public let highlights: HighlightList?
    public let digest: TodayDigest?
    public let regionUF: String?
    public let regionName: String?
    public let method: WeightMethod?
    public let hidesRaces: Bool

    public init(
        following: [PersonCard] = [], activities: [FollowingFeed.Activity] = [],
        actions: [String: ActionList] = [:], speeches: [String: [Speech]] = [:],
        recent: [VoteSummary] = [], highlights: HighlightList? = nil, digest: TodayDigest? = nil,
        regionUF: String? = nil, regionName: String? = nil, method: WeightMethod? = nil,
        hidesRaces: Bool = false
    ) {
        self.following = following
        self.activities = activities
        self.actions = actions
        self.speeches = speeches
        self.recent = recent
        self.highlights = highlights
        self.digest = digest
        self.regionUF = regionUF
        self.regionName = regionName
        self.method = method
        self.hidesRaces = hidesRaces
    }
}

public enum FeedTimeline {
    public static func build(_ sources: FeedSources) -> [FeedItem] {
        var builder = Builder(method: sources.method ?? sources.highlights?.method)
        for activity in sources.activities { builder.add(activity) }
        for card in sources.following {
            if let list = sources.actions[card.slug] { builder.add(list, by: card) }
            for speech in sources.speeches[card.slug] ?? [] { builder.add(speech, by: card) }
        }
        for vote in sources.recent { builder.add(vote) }
        let pinned = sources.highlights?.items.first?.id
        for item in sources.highlights?.items ?? [] where item.id != pinned {
            builder.add(item, reason: reason(of: item, in: sources))
        }
        if let digest = sources.digest { builder.add(digest, hidesRaces: sources.hidesRaces) }
        if let lead = sources.highlights?.items.first { builder.remove(lead) }
        return builder.items
    }

    public static func filtered(_ items: [FeedItem], by filter: FeedFilter) -> [FeedItem] {
        switch filter {
        case .all: items
        case .following: items.filter(\.isFollowing)
        case .relevant: items.filter { !$0.isFollowing }
        }
    }

    private static func reason(of item: Highlight, in sources: FeedSources) -> FeedReason {
        guard let uf = sources.regionUF, let name = sources.regionName,
            item.person?.uf.lowercased() == uf.lowercased()
        else { return .relevant }
        return .region(name)
    }

    private struct Builder {
        let method: WeightMethod?
        private var found: [String: FeedItem] = [:]

        init(method: WeightMethod?) {
            self.method = method
        }

        var items: [FeedItem] {
            found.values.sorted { lhs, rhs in
                lhs.date == rhs.date ? lhs.id < rhs.id : lhs.date > rhs.date
            }
        }

        mutating func add(_ activity: FollowingFeed.Activity) {
            let card = activity.person
            for vote in activity.votes {
                merge(
                    FeedItem(
                        id: Self.voteKey(vote.voteId), kind: .vote, date: vote.date,
                        title: vote.summary, reference: vote.proposition,
                        ballots: [SupportBallot(person: card, vote: vote.vote)],
                        reason: .following, themes: vote.themes, voteID: vote.voteId))
            }
            for check in activity.checks {
                merge(
                    FeedItem(
                        id: "check-\(check.id)", kind: .check, date: check.date, title: check.title,
                        detail: [check.verdict, check.publisher].compactMap(\.self)
                            .joined(separator: " · "),
                        people: [card], reason: .following, url: check.url))
            }
            let year = activity.expensesYear
            for month in activity.expenses?.byMonth ?? [] where month.cents > 0 {
                guard let day = CalendarDay(year: year, month: month.month, day: 1) else {
                    continue
                }
                merge(
                    FeedItem(
                        id: "expenses-\(card.slug)-\(year)-\(month.month)", kind: .expenses,
                        date: day, title: card.name, people: [card], reason: .following,
                        expenses: FeedExpenses(
                            slug: card.slug, year: year, month: month.month, cents: month.cents)))
            }
        }

        mutating func add(_ list: ActionList, by card: PersonCard) {
            for item in list.items {
                switch item.kind {
                case .vote:
                    guard let ref = item.ref else { continue }
                    merge(
                        FeedItem(
                            id: Self.voteKey(ref), kind: .vote, date: item.date, title: item.title,
                            reference: item.proposition,
                            ballots: item.ballot.map { [SupportBallot(person: card, vote: $0)] }
                                ?? [],
                            people: item.ballot == nil ? [card] : [], reason: .following,
                            themes: item.themes, voteID: ref))
                case .proposal:
                    merge(
                        FeedItem(
                            id: Self.actionKey(item.id), kind: .proposal, date: item.date,
                            title: item.title, reference: item.proposition, people: [card],
                            reason: .following, themes: item.themes,
                            content: ContentDetail(
                                action: item, person: card, method: method, sourceLine: nil)))
                case .speech:
                    continue
                }
            }
        }

        mutating func add(_ speech: Speech, by card: PersonCard) {
            let id = "speech-\(card.slug)-\(speech.date)-\(speech.summary.prefix(32))"
            merge(
                FeedItem(
                    id: id, kind: .speech, date: speech.date, title: speech.summary,
                    reference: speech.kind, people: [card], reason: .following,
                    content: ContentDetail(
                        id: id, kind: .speech, title: speech.summary, reference: speech.kind,
                        date: speech.date, url: speech.url, person: card)))
        }

        mutating func add(_ vote: VoteSummary) {
            merge(
                FeedItem(
                    id: Self.voteKey(vote.id), kind: .vote, date: vote.date,
                    title: vote.plainSummary ?? vote.summary, reference: vote.proposition,
                    reason: .relevant, themes: vote.themes, voteID: vote.id))
        }

        mutating func add(_ item: Highlight, reason: FeedReason) {
            if item.kind == .vote {
                merge(
                    FeedItem(
                        id: Self.voteKey(item.route), kind: .vote, date: item.date,
                        title: item.plainSummary ?? item.title, reference: item.proposition,
                        reason: reason, themes: item.themes ?? [], voteID: item.route))
                return
            }
            let content = ContentDetail(highlight: item, method: method, sourceLine: nil)
            let isAction = item.kind == .action && item.id.hasPrefix("action-")
            merge(
                FeedItem(
                    id: isAction
                        ? Self.actionKey(String(item.id.dropFirst("action-".count))) : item.id,
                    kind: item.kind == .action ? .proposal : .highlight, date: item.date,
                    title: content.title, reference: item.proposition,
                    people: item.person.map { [$0] } ?? [], reason: reason,
                    themes: item.themes ?? [], content: content))
        }

        mutating func add(_ digest: TodayDigest, hidesRaces: Bool) {
            for event in digest.events {
                switch event.kind {
                case .race where hidesRaces: continue
                case .vote:
                    guard let ref = event.ref else { continue }
                    merge(
                        FeedItem(
                            id: Self.voteKey(ref), kind: .vote, date: digest.date,
                            title: event.title,
                            detail: event.summary, reason: .relevant, themes: event.themes,
                            voteID: ref))
                case .race, .session, .law:
                    let id = "event-\(digest.date)-\(event.title.prefix(32))"
                    merge(
                        FeedItem(
                            id: id, kind: .event, date: digest.date, title: event.title,
                            detail: event.summary, reason: .relevant, themes: event.themes,
                            content: ContentDetail(
                                id: id, kind: .event, title: event.title,
                                plainSummary: event.summary, date: digest.date,
                                themes: event.themes)))
                }
            }
        }

        mutating func remove(_ lead: Highlight) {
            if lead.kind == .vote {
                found[Self.voteKey(lead.route)] = found[Self.voteKey(lead.route)].flatMap {
                    $0.isFollowing ? $0 : nil
                }
            } else if lead.id.hasPrefix("action-") {
                found[Self.actionKey(String(lead.id.dropFirst("action-".count)))] = nil
            }
        }

        private mutating func merge(_ item: FeedItem) {
            guard let current = found[item.id] else {
                found[item.id] = item
                return
            }
            let ballots = Self.unique(current.ballots + item.ballots, by: \.person.slug)
                .sorted {
                    $0.person.name.localizedStandardCompare($1.person.name) == .orderedAscending
                }
            let voters = Set(ballots.map(\.person.slug))
            let people = Self.unique(current.people + item.people, by: \.slug)
                .filter { !voters.contains($0.slug) }
            let plain = item.reason.rank == FeedReason.relevant.rank
            found[item.id] = FeedItem(
                id: current.id, kind: current.kind, date: max(current.date, item.date),
                title: plain ? item.title : current.title, detail: current.detail ?? item.detail,
                reference: current.reference ?? item.reference, ballots: ballots, people: people,
                reason: current.reason.rank <= item.reason.rank ? current.reason : item.reason,
                themes: Self.unique(current.themes + item.themes, by: \.rawValue),
                voteID: current.voteID ?? item.voteID, expenses: current.expenses ?? item.expenses,
                content: current.content ?? item.content, url: current.url ?? item.url)
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
