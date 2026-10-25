import FeatureCore
import FiscalDomain
import Foundation
import Observation

@MainActor @Observable
public final class TodayModel {
    public struct Representative: Hashable, Identifiable {
        public let card: PersonCard
        public let vote: VoteSummary?
        public let ballot: TodayBallot?

        public var id: String { card.slug }
    }

    public struct HouseAgenda: Hashable, Identifiable {
        public let day: Agenda.HouseDay
        public let items: [LensOrdered<AgendaItem>]

        public var id: House { day.house }
    }

    public static let recentLimit = 3
    public static let representativesLimit = 4
    public static let agendaLimit = 3

    public private(set) var digest: TodayDigest?
    public private(set) var agenda: Agenda?
    public private(set) var recentVotes: [VoteSummary] = []
    public private(set) var races: [Race] = []
    public private(set) var racesOffline = false
    public private(set) var followed: [PersonCard] = []
    public private(set) var ballots: [String: String] = [:]
    public private(set) var latestVotes: [House: VoteSummary] = [:]
    public private(set) var lens: Lens?
    public private(set) var hasCheckedLens = false
    public private(set) var phase: PublicDataPhase = .idle
    @ObservationIgnored private let service: (any PublicDataService)?
    @ObservationIgnored private let lensRepository: (any LensRepository)?
    @ObservationIgnored private let raceService: (any LiveResultsService)?
    @ObservationIgnored private let follows: (any FollowRepository)?
    @ObservationIgnored private let raceInterval: Duration

    public init(
        service: (any PublicDataService)?, lens: (any LensRepository)? = nil,
        races: (any LiveResultsService)? = nil, follows: (any FollowRepository)? = nil,
        raceInterval: Duration = .seconds(20)
    ) {
        self.service = service
        lensRepository = lens
        raceService = races
        self.follows = follows
        self.raceInterval = raceInterval
    }

    public var mode: TodayBriefing.Mode { TodayBriefing.mode(for: lens) }

    public var stance: PoliticalStance? { lens?.stance }

    public var lensLine: String? { TodayText.lensLine(lens) }

    public var dateLine: String {
        TodayText.dateLine(digest?.date ?? agenda?.date ?? CalendarDay(.now))
    }

    public var events: [TodayDigest.Event] { ordered(digest?.events ?? []).map(\.value) }

    public var briefing: [LensOrdered<TodayDigest.Event>] {
        let events = (digest?.events ?? []).filter { liveBoard == nil || $0.kind != .race }
        return ordered(events)
    }

    public var lead: LensOrdered<TodayDigest.Event>? { briefing.first }

    public var others: [LensOrdered<TodayDigest.Event>] { Array(briefing.dropFirst()) }

    public var isEmpty: Bool { digest?.events.isEmpty ?? true }

    public var hasLoadedDigest: Bool { digest != nil }

    public var sources: [Source] { digest?.sources ?? [] }

    public var digestSource: String? { TodayText.sourceLine(sources) }

    public var liveBoard: TodayRaceBoard? {
        guard let race = TodayRaceBoard.featured(in: races) else { return nil }
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
        (agenda?.houses ?? []).map { day in
            HouseAgenda(
                day: day, items: TodayBriefing.order(day.items, mode: mode, themes: \.themes))
        }
    }

    public var agendaSource: String? {
        guard let agenda, !agenda.houses.isEmpty else { return nil }
        let date = TodayText.shortDate(agenda.date.date())
        return TodayText.houseSourceLine(
            agenda.houses.map(\.house), suffix: String(appLocalized: "agenda of \(date)"))
    }

    public var recent: [VoteSummary] {
        let featured = lead.flatMap { leadVote(for: $0.value) }?.id
        return Array(recentVotes.filter { $0.id != featured }.prefix(Self.recentLimit))
    }

    public var recentSource: String? {
        guard let latest = recentVotes.map(\.date).max() else { return nil }
        let date = TodayText.shortDate(latest.date())
        return TodayText.houseSourceLine(
            recentVotes.map(\.house), suffix: String(appLocalized: "votes up to \(date)"))
    }

    public var representatives: [Representative] {
        followed.prefix(Self.representativesLimit).map { card in
            let vote = Self.house(for: card.office).flatMap { latestVotes[$0] }
            return Representative(
                card: card, vote: vote, ballot: ballots[card.slug].map(TodayBallot.init))
        }
    }

    public var moreFollowed: Int { max(followed.count - Self.representativesLimit, 0) }

    public func detail(for card: PersonCard) -> String {
        card.uf == "br" ? card.office.title : "\(card.office.title) · \(card.uf.uppercased())"
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
        lens = try? await lensRepository?.lens()
        hasCheckedLens = true
        async let people = loadFollowed()
        async let liveRaces: Void = refreshRaces()
        phase = await PublicDataPhase.settle(after: phase) {
            guard let service else { throw PublicDataError.unavailable }
            async let today = service.today()
            async let agenda = service.agenda()
            async let votes = service.recentVotes()
            digest = try await today
            if let value = try? await agenda { self.agenda = value }
            if let value = try? await votes { recentVotes = value }
        }
        followed = await people
        await liveRaces
        await loadBallots()
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
        while !Task.isCancelled, liveBoard != nil {
            try? await Task.sleep(for: raceInterval)
            guard !Task.isCancelled else { return }
            await refreshRaces()
        }
    }

    private func ordered(_ events: [TodayDigest.Event]) -> [LensOrdered<TodayDigest.Event>] {
        TodayBriefing.order(events, mode: mode, themes: \.themes)
    }

    private func loadFollowed() async -> [PersonCard] {
        let people = (try? await follows?.followed()) ?? []
        return people.map(\.card).sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    private func loadBallots() async {
        guard let service else { return }
        let houses = Set(followed.compactMap { Self.house(for: $0.office) })
        var latest: [House: VoteSummary] = [:]
        for house in houses {
            latest[house] = recentVotes.filter { $0.house == house }.max { $0.date < $1.date }
        }
        var found: [String: String] = [:]
        for vote in latest.values {
            guard let detail = try? await service.vote(id: vote.id) else { continue }
            for ballot in detail.people {
                if let slug = ballot.slug { found[slug] = ballot.vote }
            }
        }
        latestVotes = latest
        ballots = found
    }

    static func house(for office: Office) -> House? {
        switch office {
        case .federalDeputy: .camara
        case .senator: .senado
        case .president, .vicePresident, .governor, .viceGovernor, .stateDeputy: nil
        }
    }
}
