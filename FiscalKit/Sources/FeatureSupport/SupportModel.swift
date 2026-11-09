import FeatureCore
import FiscalDomain
import Foundation
import Observation

@MainActor @Observable
public final class SupportModel {
    public struct MonthSection: Identifiable, Equatable {
        public let id: String
        public let title: String
        public let events: [SupportEvent]
    }

    public private(set) var cards: [PersonCard] = []
    public private(set) var events: [SupportEvent] = []
    public private(set) var phase: PublicDataPhase = .idle
    public private(set) var hasGaps = false
    public var filter: SupportFilter = .all
    public var isEditing = false
    public var isConfirmingErase = false
    public private(set) var isErasing = false
    @ObservationIgnored private let context: SupportContext
    @ObservationIgnored private let service: (any PublicDataService)?
    @ObservationIgnored private let follows: (any FollowRepository)?
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let requests = PublicDataRequests()

    public init(
        context: SupportContext, service: (any PublicDataService)?,
        follows: (any FollowRepository)?, now: @escaping () -> Date = Date.init
    ) {
        self.context = context
        self.service = service
        self.follows = follows
        self.now = now
    }

    public var choice: SupportChoice { context.choice }

    public var hasChoice: Bool { !choice.isEmpty }

    public var isEmpty: Bool { events.isEmpty && hasChoice }

    public var visible: [SupportEvent] { SupportTimeline.filtered(events, by: filter) }

    public var sections: [MonthSection] {
        var sections: [MonthSection] = []
        for event in visible {
            let id = Self.monthID(event.date)
            if let last = sections.last, last.id == id {
                sections[sections.count - 1] = MonthSection(
                    id: id, title: last.title, events: last.events + [event])
            } else {
                sections.append(
                    MonthSection(id: id, title: Self.monthTitle(event.date), events: [event]))
            }
        }
        return sections
    }

    public var causes: [Theme] { choice.causes }

    public var isAtTheLimit: Bool { events.count >= SupportTimeline.limit }

    public func load() async {
        await context.load()
        filter = validFilter
        guard hasChoice else {
            cards = []
            events = []
            phase = .loaded
            return
        }
        if events.isEmpty { phase = .loading }
        phase = await PublicDataPhase.settle(after: phase, in: requests) { [self] in
            guard let service else { throw PublicDataError.unavailable }
            return try await fetch(from: service)
        } apply: { [self] loaded in
            cards = loaded.sources.cards
            hasGaps = loaded.hasGaps
            events = SupportTimeline.build(choice, from: loaded.sources)
        }
    }

    public func erase() async {
        isErasing = true
        defer { isErasing = false }
        if await context.erase() {
            isConfirmingErase = false
            filter = .all
            await load()
        }
    }

    public func title(for filter: SupportFilter) -> String {
        switch filter {
        case .all: String(appLocalized: "All")
        case .person(let slug): cards.first { $0.slug == slug }?.name ?? slug
        case .cause(let cause): cause.title
        }
    }

    public var emptyMessage: String {
        switch filter {
        case .all:
            String(appLocalized: "Nothing recent from the official sources yet.")
        case .person(let slug):
            String(appLocalized: "Nothing recent from \(title(for: .person(slug))).")
        case .cause(let cause):
            String(appLocalized: "No recent vote or proposal is tagged \(cause.title).")
        }
    }

    public var votesNote: String? {
        guard case .person(let slug) = filter,
            let card = cards.first(where: { $0.slug == slug }), !card.office.publishesVotes
        else { return nil }
        return String(appLocalized: "The source does not publish votes for \(card.officeTitle).")
    }

    public var footnote: String {
        let base = String(
            appLocalized:
                "From the official sources, newest first. Recent activity, not the full history.")
        guard isAtTheLimit else { return base }
        return String(appLocalized: "\(base) Showing the \(SupportTimeline.limit) most recent.")
    }

    public func kicker(_ event: SupportEvent) -> String {
        let kind =
            switch event.kind {
            case .vote: String(appLocalized: "Vote")
            case .proposal: String(appLocalized: "Proposal")
            case .speech: String(appLocalized: "Speech")
            case .highlight: String(appLocalized: "Highlight")
            }
        return [kind, event.reference].compactMap(\.self).joined(separator: " · ")
    }

    public func marked(_ event: SupportEvent) -> [Theme] {
        event.themes.filter(choice.contains)
    }

    public func causesLine(_ event: SupportEvent) -> String? {
        let titles = marked(event).map(\.title)
        return titles.isEmpty ? nil : titles.joined(separator: " · ")
    }

    public func ballotText(_ ballot: SupportBallot) -> String {
        BallotChoice(vote: ballot.vote)?.title ?? ballot.vote
    }

    public func accessibility(_ event: SupportEvent) -> String {
        let ballots = event.ballots.map { "\($0.person.name): \(ballotText($0))" }
        let people = event.people.map(\.name)
        return
            ([SourceFootnote.day(event.date), kicker(event), event.title] + ballots + people
            + marked(event).map(\.title))
            .joined(separator: ". ")
    }

    private var validFilter: SupportFilter {
        switch filter {
        case .person(let slug) where !choice.supports(slug): .all
        case .cause(let cause) where !choice.contains(cause): .all
        default: filter
        }
    }

    private func fetch(from service: any PublicDataService) async throws -> (
        sources: SupportSources, hasGaps: Bool
    ) {
        let year = Calendar.current.component(.year, from: now())
        let cards = await SupportedPeople.cards(
            for: choice.people, service: service, follows: follows)
        if cards.isEmpty, !choice.people.isEmpty { _ = try await service.people() }
        let needsCauses = !choice.causes.isEmpty
        async let recent = Self.attempt(needsCauses) { try await service.recentVotes() }
        async let highlights = Self.attempt(needsCauses) { try await service.highlights() }
        async let method = Self.attempt(true) { try await service.weightMethod() }
        let activity = await withTaskGroup(of: PersonActivityResult.self) { group in
            for card in cards {
                group.addTask { await Self.activity(of: card, year: year, from: service) }
            }
            var all: [PersonActivityResult] = []
            for await item in group { all.append(item) }
            return all
        }
        let loadedRecent = await recent
        let loadedHighlights = await highlights
        let causesFailed = needsCauses && (loadedRecent == nil || loadedHighlights == nil)
        let causesAllFailed = needsCauses && loadedRecent == nil && loadedHighlights == nil
        let peopleAllFailed = !activity.isEmpty && activity.allSatisfy(\.failed)
        if peopleAllFailed && (causesAllFailed || !needsCauses) {
            throw PublicDataError.unavailable
        }
        if activity.isEmpty && causesAllFailed { throw PublicDataError.unavailable }
        var actions: [String: ActionList] = [:]
        var votes: [String: [PersonVote]] = [:]
        for item in activity {
            actions[item.slug] = item.actions
            votes[item.slug] = item.votes?.items
        }
        let sources = SupportSources(
            cards: cards, actions: actions, votes: votes, recent: loadedRecent ?? [],
            highlights: loadedHighlights ?? nil, method: await method ?? nil)
        return (sources, causesFailed || activity.contains(where: \.failed))
    }

    private struct PersonActivityResult: Sendable {
        let slug: String
        let actions: ActionList?
        let votes: PublicList<PersonVote>?
        let failed: Bool
    }

    private static func activity(
        of card: PersonCard, year: Int, from service: any PublicDataService
    ) async -> PersonActivityResult {
        var failed = false
        var actions: ActionList?
        var votes: PublicList<PersonVote>?
        do {
            actions = try await service.actions(slug: card.slug)
        } catch {
            failed = true
        }
        if card.office.publishesVotes {
            do {
                votes = try await service.votes(slug: card.slug, year: year)
            } catch PublicDataError.notFound {
                votes = nil
            } catch {
                failed = true
            }
        }
        return PersonActivityResult(slug: card.slug, actions: actions, votes: votes, failed: failed)
    }

    private static func attempt<Value: Sendable>(
        _ needed: Bool, _ fetch: @Sendable () async throws -> Value
    ) async -> Value? {
        guard needed else { return nil }
        return try? await fetch()
    }

    private static func monthID(_ day: CalendarDay) -> String {
        day.date().formatted(.iso8601.year().month())
    }

    private static func monthTitle(_ day: CalendarDay) -> String {
        let title = day.date().formatted(.dateTime.month(.wide).year().locale(.app))
        return title.prefix(1).uppercased(with: .app) + title.dropFirst()
    }
}
