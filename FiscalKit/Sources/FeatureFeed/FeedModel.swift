import FeatureCore
import FiscalDomain
import Foundation
import Observation
import WidgetKit

@MainActor @Observable
public final class FeedModel {
    public nonisolated static let firstYear = 2023
    public nonisolated static let pageSize = 20
    nonisolated static let concurrentReads = 6

    public private(set) var items: [FeedItem] = []
    public private(set) var followed: [PersonCard] = []
    @ObservationIgnored private var followedAt: [String: Date] = [:]
    public private(set) var missing: [PersonCard] = []
    public private(set) var phase: PublicDataPhase = .idle
    public private(set) var isLoadingMore = false
    public private(set) var reachedEnd = false
    public private(set) var hasLoaded = false
    public private(set) var seenVersion = 0
    public private(set) var races: [Race] = []
    public private(set) var racesOffline = false
    public private(set) var highlights: HighlightList?
    public private(set) var shownCount = FeedModel.pageSize
    public var filter: FeedFilter = .all {
        didSet { shownCount = Self.pageSize }
    }
    @ObservationIgnored private let service: (any PublicDataService)?
    @ObservationIgnored private let raceService: (any LiveResultsService)?
    @ObservationIgnored private let raceInterval: Duration
    @ObservationIgnored private let follows: (any FollowRepository)?
    @ObservationIgnored private let seenStore: FollowingSeenStore
    @ObservationIgnored private let regionUF: () -> String?
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let publishesSnapshot: Bool
    @ObservationIgnored private let requests = PublicDataRequests()
    @ObservationIgnored private var activities: [FollowingFeed.Activity] = []
    @ObservationIgnored private var actions: [String: ActionList] = [:]
    @ObservationIgnored private var speeches: [String: [Speech]] = [:]
    @ObservationIgnored private var recent: [VoteSummary] = []
    @ObservationIgnored private var digest: TodayDigest?
    private var oldestYear = 0
    @ObservationIgnored private var loadGeneration = 0
    @ObservationIgnored private var hidesRaces = false

    public init(
        service: (any PublicDataService)?, races: (any LiveResultsService)? = nil,
        follows: (any FollowRepository)?, raceInterval: Duration = .seconds(20),
        seen: FollowingSeenStore = FollowingSeenStore(),
        regionUF: @escaping () -> String? = { HomePlace.chosenUF(in: .standard) },
        now: @escaping () -> Date = Date.init, publishesSnapshot: Bool = true
    ) {
        self.service = service
        raceService = races
        self.raceInterval = raceInterval
        self.follows = follows
        seenStore = seen
        self.regionUF = regionUF
        self.now = now
        self.publishesSnapshot = publishesSnapshot
    }

    private var matching: [FeedItem] {
        let found = FeedTimeline.filtered(items, by: filter)
        guard !reachedEnd, filter != .relevant else { return found }
        return found.filter { $0.date.year >= oldestYear }
    }

    var currentYear: Int { CalendarDay(now()).year }

    public var visible: [FeedItem] { Array(matching.prefix(shownCount)) }

    public var isAtEnd: Bool {
        guard matching.count <= shownCount else { return false }
        return reachedEnd || filter == .relevant
    }

    public var isEmpty: Bool { items.isEmpty }

    public var followsNobody: Bool { hasLoaded && followed.isEmpty }

    public var updates: [FollowingUpdate] {
        FollowingFeed.build(activities, today: CalendarDay(now()))
    }

    public var newCount: Int {
        _ = seenVersion
        return FollowingFeed.newCount(updates, seen: lastSeen)
    }

    public var liveBoard: FeedRaceBoard? {
        guard let race = FeedRaceBoard.featured(in: races, now: now()) else { return nil }
        let others = races.filter { !$0.final && $0.id != race.id }.count
        return FeedRaceBoard(race: race, others: others, isStale: racesOffline)
    }

    public var notice: (text: String, symbol: String)? {
        guard hasLoaded, let error = phase.error else { return nil }
        return error == .offline
            ? (
                String(appLocalized: "No connection. Showing the last facts received."),
                "wifi.slash"
            )
            : (error.message, error.symbol)
    }

    public var missingText: String {
        let names = missing.map(\.name).formatted(.list(type: .and).locale(.app))
        return String(appLocalized: "Couldn't load \(names). Pull to try again.")
    }

    public var endMessage: String {
        guard missing.isEmpty else { return missingText }
        guard followed.isEmpty else {
            if filter == .relevant {
                return String(appLocalized: "These are the most recent relevant facts.")
            }
            return String(
                appLocalized: "That is all: the official data here goes back to \(Self.firstYear).")
        }
        return String(appLocalized: "That is all for now. Follow people to see more facts here.")
    }

    public var emptyMessage: String {
        switch filter {
        case .following:
            followed.isEmpty
                ? String(appLocalized: "Follow people to see what they do here.")
                : String(appLocalized: "Nothing yet from who you follow.")
        case .all, .relevant:
            String(appLocalized: "Nothing recent from the official sources yet.")
        }
    }

    public func load() async {
        if items.isEmpty { phase = .loading }
        loadGeneration += 1
        async let liveRaces: Void = refreshRaces()
        let years = FollowingFeed.years(for: CalendarDay(now()))
        let year = years.min() ?? Self.firstYear
        phase = await PublicDataPhase.settle(after: phase, in: requests) { [self] in
            guard let service else { throw PublicDataError.unavailable }
            let following = (try? await follows?.followed()) ?? []
            let people = following.map(\.card)
            async let digest = service.today()
            async let recent = service.recentVotes()
            async let highlights = service.highlights()
            let loaded = await Self.read(people, years: years, first: true, from: service)
            let page = Page(
                digest: try? await digest, recent: try? await recent,
                highlights: (try? await highlights) ?? nil)
            if page.digest == nil, page.recent == nil, page.highlights == nil, !people.isEmpty,
                loaded.missing.count == people.count
            {
                throw PublicDataError.unavailable
            }
            if page.digest == nil, page.recent == nil, page.highlights == nil, people.isEmpty {
                throw PublicDataError.unavailable
            }
            return (following, loaded, page)
        } apply: { [self] result in
            let (following, loaded, page) = result
            let people = following.map(\.card)
            followed = people
            followedAt = Dictionary(
                following.map { ($0.card.slug, $0.followedAt) },
                uniquingKeysWith: { first, _ in first })
            missing = loaded.missing
            activities = loaded.activities
            actions = loaded.actions
            speeches = loaded.speeches
            if let value = page.digest { digest = value }
            if let value = page.recent { recent = value }
            if let value = page.highlights { highlights = value }
            oldestYear = year
            reachedEnd = people.isEmpty || year <= Self.firstYear
            hasLoaded = true
            shownCount = Self.pageSize
            rebuild()
            publishSnapshot()
        }
        await liveRaces
    }

    public func refreshRaces() async {
        guard let raceService else { return }
        do {
            races = try await raceService.races()
            racesOffline = false
            if hasLoaded, hidesRaces != (liveBoard != nil) { rebuild() }
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

    public func loadMore() async {
        guard hasLoaded else { return }
        let shown = shownCount
        if matching.count > shown {
            shownCount = shown + Self.pageSize
            return
        }
        guard !isLoadingMore, !reachedEnd, filter != .relevant, let service else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        let generation = loadGeneration
        var year = oldestYear
        let before = matching.count
        while matching.count == before, year > Self.firstYear {
            year -= 1
            let loaded = await Self.read(followed, years: [year], first: false, from: service)
            guard generation == loadGeneration else { return }
            activities += loaded.activities
            missing = Self.merged(missing, loaded.missing)
            for (slug, list) in loaded.speeches { speeches[slug, default: []] += list }
            oldestYear = year
            rebuild()
        }
        reachedEnd = oldestYear <= Self.firstYear
        if matching.count > before { shownCount = shown + Self.pageSize }
    }

    private static func merged(_ current: [PersonCard], _ new: [PersonCard]) -> [PersonCard] {
        let known = Set(current.map(\.slug))
        return (current + new.filter { !known.contains($0.slug) })
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    public func followsChanged(to slugs: Set<String>) async {
        guard hasLoaded, Set(followed.map(\.slug)) != slugs else { return }
        await load()
    }

    public func markSeen() {
        let slugs = followed.map(\.slug)
        guard !slugs.isEmpty else { return }
        seenStore.markSeen(slugs, at: now())
        seenStore.forget(keeping: Set(slugs))
        seenVersion += 1
    }

    private func lastSeen(_ slug: String) -> Date? {
        seenStore.seen(slug) ?? followedAt[slug]
    }

    private func publishSnapshot() {
        guard publishesSnapshot else { return }
        let snapshot = FollowingSnapshot.make(followed: followed, updates: updates, at: now())
        try? snapshot.write()
        WidgetCenter.shared.reloadTimelines(ofKind: FollowingWidget.kind)
    }

    private func rebuild() {
        let uf = regionUF()
        hidesRaces = liveBoard != nil
        let built = FeedTimeline.build(
            FeedSources(
                following: followed, activities: activities, actions: actions, speeches: speeches,
                recent: recent, highlights: highlights, digest: digest, regionUF: uf,
                regionName: uf.map(HomePlace.name(of:)), method: highlights?.method,
                hidesRaces: hidesRaces))
        if built != items { items = built }
    }

    private struct Page: Sendable {
        let digest: TodayDigest?
        let recent: [VoteSummary]?
        let highlights: HighlightList?
    }
}
