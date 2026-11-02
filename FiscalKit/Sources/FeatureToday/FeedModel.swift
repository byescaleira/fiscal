import FeatureCore
import FiscalDomain
import Foundation
import Observation

@MainActor @Observable
public final class FeedModel {
    public nonisolated static let firstYear = 2023
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
    public var filter: FeedFilter = .all
    @ObservationIgnored private let service: (any PublicDataService)?
    @ObservationIgnored private let follows: (any FollowRepository)?
    @ObservationIgnored private let seenStore: FollowingSeenStore
    @ObservationIgnored private let regionUF: () -> String?
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let requests = PublicDataRequests()
    @ObservationIgnored private var activities: [FollowingFeed.Activity] = []
    @ObservationIgnored private var actions: [String: ActionList] = [:]
    @ObservationIgnored private var speeches: [String: [Speech]] = [:]
    @ObservationIgnored private var recent: [VoteSummary] = []
    @ObservationIgnored private var highlights: HighlightList?
    @ObservationIgnored private var digest: TodayDigest?
    @ObservationIgnored private var oldestYear = 0

    public init(
        service: (any PublicDataService)?, follows: (any FollowRepository)?,
        seen: FollowingSeenStore = FollowingSeenStore(),
        regionUF: @escaping () -> String? = { HomePlace.chosenUF(in: .standard) },
        now: @escaping () -> Date = Date.init
    ) {
        self.service = service
        self.follows = follows
        seenStore = seen
        self.regionUF = regionUF
        self.now = now
    }

    public var visible: [FeedItem] { FeedTimeline.filtered(items, by: filter) }

    public var isEmpty: Bool { items.isEmpty }

    public var followsNobody: Bool { hasLoaded && followed.isEmpty }

    public var updates: [FollowingUpdate] {
        FollowingFeed.build(activities, today: CalendarDay(now()))
    }

    public var newCount: Int {
        _ = seenVersion
        return FollowingFeed.newCount(updates, seen: lastSeen)
    }

    public var missingText: String {
        let names = missing.map(\.name).formatted(.list(type: .and).locale(.app))
        return String(appLocalized: "Couldn't load \(names). Pull to try again.")
    }

    public var endMessage: String {
        guard followed.isEmpty else {
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
        let year = Calendar.current.component(.year, from: now())
        phase = await PublicDataPhase.settle(after: phase, in: requests) { [self] in
            guard let service else { throw PublicDataError.unavailable }
            let following = (try? await follows?.followed()) ?? []
            let people = following.map(\.card)
            async let digest = service.today()
            async let recent = service.recentVotes()
            async let highlights = service.highlights()
            let loaded = await Self.read(people, years: [year], first: true, from: service)
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
            digest = page.digest
            recent = page.recent ?? []
            highlights = page.highlights
            oldestYear = year
            reachedEnd = people.isEmpty || year <= Self.firstYear
            hasLoaded = true
            rebuild()
        }
    }

    public func loadMore() async {
        guard !isLoadingMore, !reachedEnd, hasLoaded, let service else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        var year = oldestYear
        var grew = false
        while !grew, year > Self.firstYear {
            year -= 1
            let loaded = await Self.read(followed, years: [year], first: false, from: service)
            activities += loaded.activities
            for (slug, list) in loaded.speeches { speeches[slug, default: []] += list }
            let before = items.count
            rebuild()
            grew = items.count > before
            oldestYear = year
        }
        reachedEnd = oldestYear <= Self.firstYear
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

    private func rebuild() {
        let uf = regionUF()
        items = FeedTimeline.build(
            FeedSources(
                following: followed, activities: activities, actions: actions, speeches: speeches,
                recent: recent, highlights: highlights, digest: digest, regionUF: uf,
                regionName: uf.map(HomePlace.name(of:)), method: highlights?.method))
    }

    private struct Page: Sendable {
        let digest: TodayDigest?
        let recent: [VoteSummary]?
        let highlights: HighlightList?
    }
}
