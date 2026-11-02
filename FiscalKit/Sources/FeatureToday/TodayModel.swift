import FeatureCore
import FiscalDomain
import Foundation
import Observation

@MainActor @Observable
public final class TodayModel {
    public struct HouseAgenda: Hashable, Identifiable {
        public let day: Agenda.HouseDay
        public let items: [AgendaItem]

        public var id: House { day.house }
    }

    public static let recentLimit = 3
    public static let agendaLimit = 3

    public private(set) var digest: TodayDigest?
    public private(set) var agenda: Agenda?
    public private(set) var recentVotes: [VoteSummary] = []
    public private(set) var highlights: HighlightList?
    public private(set) var races: [Race] = []
    public private(set) var racesOffline = false
    public private(set) var followedCount = 0
    public private(set) var phase: PublicDataPhase = .idle
    @ObservationIgnored private let service: (any PublicDataService)?
    @ObservationIgnored private let raceService: (any LiveResultsService)?
    @ObservationIgnored private let follows: (any FollowRepository)?
    @ObservationIgnored private let raceInterval: Duration
    @ObservationIgnored private let requests = PublicDataRequests()
    @ObservationIgnored let now: @Sendable () -> Date

    public init(
        service: (any PublicDataService)?, races: (any LiveResultsService)? = nil,
        follows: (any FollowRepository)? = nil,
        raceInterval: Duration = .seconds(20), now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.service = service
        raceService = races
        self.follows = follows
        self.raceInterval = raceInterval
        self.now = now
    }

    public var events: [TodayDigest.Event] { digest?.events ?? [] }

    public var briefing: [TodayDigest.Event] {
        TodayBriefing.events(events, hidesRaces: liveBoard != nil)
    }

    public var lead: TodayDigest.Event? { briefing.first }

    public var others: [TodayDigest.Event] { Array(briefing.dropFirst()) }

    public var isEmpty: Bool { digest?.events.isEmpty ?? true }

    public var hasLoadedDigest: Bool { digest != nil }

    public var sources: [Source] { digest?.sources ?? [] }

    public var liveBoard: TodayRaceBoard? {
        guard let race = TodayRaceBoard.featured(in: races, now: now()) else { return nil }
        let others = races.filter { !$0.final && $0.id != race.id }.count
        return TodayRaceBoard(race: race, others: others, isStale: racesOffline)
    }

    public func leadVote(for event: TodayDigest.Event) -> VoteSummary? {
        guard event.kind == .vote, let ref = event.ref else { return nil }
        return recentVotes.first { $0.id == ref }
    }

    public func route(for event: TodayDigest.Event) -> Route? {
        switch event.kind {
        case .vote: event.ref.map { .vote(id: $0) }
        case .race: .races
        case .session, .law: nil
        }
    }

    public func shareSubject(for event: TodayDigest.Event) -> ShareSubject? {
        switch event.kind {
        case .vote: event.ref.map { .vote(id: $0) }
        case .race: event.ref.map { .race(id: $0) }
        case .session, .law: nil
        }
    }

    public var houses: [HouseAgenda] {
        (agenda?.houses ?? []).map { HouseAgenda(day: $0, items: $0.items) }
    }

    public var recent: [VoteSummary] {
        let featured = lead.flatMap(leadVote(for:))?.id
        return Array(recentVotes.filter { $0.id != featured }.prefix(Self.recentLimit))
    }

    public var notice: (text: String, symbol: String)? {
        guard hasLoadedDigest, let error = phase.error else { return nil }
        return error == .offline
            ? (
                String(appLocalized: "No connection. Showing the last summary received."),
                "wifi.slash"
            )
            : (error.message, error.symbol)
    }

    public func load() async {
        if digest == nil { phase = .loading }
        async let people = loadFollowedCount()
        async let liveRaces: Void = refreshRaces()
        phase = await PublicDataPhase.settle(after: phase, in: requests) {
            guard let service else { throw PublicDataError.unavailable }
            async let today = service.today()
            async let agenda = service.agenda()
            async let votes = service.recentVotes()
            async let highlights = service.highlights()
            return TodayPage(
                digest: try await today, agenda: try? await agenda, votes: try? await votes,
                highlights: try? await highlights)
        } apply: { page in
            digest = page.digest
            if let value = page.agenda { agenda = value }
            if let value = page.votes { recentVotes = value }
            if let value = page.highlights { highlights = value }
        }
        followedCount = await people
        await liveRaces
    }

    public func refreshRaces() async {
        guard let raceService else { return }
        do {
            races = try await raceService.races()
            racesOffline = false
        } catch is CancellationError {} catch {
            racesOffline = true
        }
    }

    public func watchRaces() async {
        guard raceService != nil else { return }
        while !Task.isCancelled, liveBoard?.race.final == false {
            try? await Task.sleep(for: raceInterval)
            guard !Task.isCancelled else { return }
            await refreshRaces()
        }
    }

    private func loadFollowedCount() async -> Int {
        (try? await follows?.followed().count) ?? 0
    }
}

private struct TodayPage {
    let digest: TodayDigest
    let agenda: Agenda?
    let votes: [VoteSummary]?
    let highlights: HighlightList?
}
