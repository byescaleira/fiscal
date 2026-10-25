import FeatureCore
import FiscalDomain
import Foundation
import Observation

@MainActor @Observable
public final class SearchModel {
    public static let defaultThemes: [Theme] = Array(Theme.allCases.prefix(6))

    public var query = ""
    public var tokens: [SearchToken] = []
    public private(set) var phase: PublicDataPhase = .idle
    public private(set) var lens: Lens?
    public private(set) var recents: [String] = []
    public private(set) var sources: [Source] = []
    public private(set) var updatedAt: Date?
    public private(set) var liveCount: LiveCount?
    @ObservationIgnored private var index = SearchIndex()
    @ObservationIgnored private let service: (any PublicDataService)?
    @ObservationIgnored private let lensRepository: (any LensRepository)?
    @ObservationIgnored private let recentStore: (any RecentSearchStore)?
    @ObservationIgnored private let races: (any LiveResultsService)?
    @ObservationIgnored private let now: @Sendable () -> Date
    private var revision = 0

    public struct LiveCount: Equatable, Sendable {
        public let counted: Double
        public let races: Int
    }

    public init(
        service: (any PublicDataService)?, lens: (any LensRepository)? = nil,
        recents: (any RecentSearchStore)? = DeviceRecentSearches(),
        races: (any LiveResultsService)? = nil, now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.service = service
        lensRepository = lens
        recentStore = recents
        self.races = races
        self.now = now
    }

    public var isSearching: Bool { !SearchText.words(query).isEmpty || !tokens.isEmpty }

    public var results: SearchResults {
        _ = revision
        return index.results(for: query, tokens: tokens)
    }

    public var hasIndex: Bool {
        _ = revision
        return !index.isEmpty
    }

    public var isLensAdapted: Bool { !(lens?.themes.isEmpty ?? true) }

    public var badgeStance: PoliticalStance? {
        isLensAdapted ? lens?.stance ?? .preferNotToSay : nil
    }

    public var comparesFirst: Bool { lens?.stance?.isImpartial ?? false }

    public var themes: [Theme] {
        guard let lens, !lens.themes.isEmpty else { return Self.defaultThemes }
        return lens.themes
    }

    public var sourceLine: String? { SourceLine.text(sources, updatedAt: updatedAt) }

    public var elections: [Election] { ElectionCalendar.elections(now: now()) }

    public var electedAwaiting: Int {
        _ = revision
        return index.count(of: .electedAwaiting)
    }

    public var suggestions: [CompareSuggestion] {
        _ = revision
        return CompareSuggestion.make(from: index.people.map(\.value))
    }

    public var placeNote: String? {
        guard let place = tokens.lazy.compactMap(\.place).first, !place.isState else {
            return nil
        }
        return String(
            appLocalized:
                "\(place.name) is represented here by the people elected in \(place.uf.uppercased()). Mayors and city councillors come after version 1.0."
        )
    }

    public func detail(for card: PersonCard) -> String {
        let place = card.uf == "br" ? "" : " · \(card.uf.uppercased())"
        return "\(card.office.title)\(place)"
    }

    public func detail(for place: Place) -> String {
        place.isState
            ? String(appLocalized: "State")
            : String(appLocalized: "City in \(place.uf.uppercased())")
    }

    public func detail(for party: PartySummary) -> String {
        String(appLocalized: "People in Fiscal: \(party.count)")
    }

    public func apply(_ token: SearchToken) {
        record()
        tokens = [token]
        query = ""
    }

    public func search(_ text: String) {
        tokens = []
        query = text
    }

    public func record() {
        guard !SearchText.words(query).isEmpty else { return }
        recents = RecentSearches.adding(query, to: recents)
        recentStore?.save(recents)
    }

    public func clearRecents() {
        recents = []
        recentStore?.save([])
    }

    public func load() async {
        lens = try? await lensRepository?.lens()
        recents = recentStore?.load() ?? []
        guard index.isEmpty else { return }
        phase = .loading
        phase = await PublicDataPhase.settle(after: phase) {
            guard let service else { throw PublicDataError.unavailable }
            async let people = service.people()
            async let places = try? service.places()
            async let votes = try? service.recentVotes()
            async let meta = try? service.meta()
            let loaded = (try await people, await places ?? [], await votes ?? [])
            index = await Task.detached {
                SearchIndex(people: loaded.0, places: loaded.1, votes: loaded.2)
            }.value
            let info = await meta
            sources = info?.sources ?? []
            updatedAt = info?.generatedAt
            revision += 1
        }
        await loadLiveCount()
    }

    private func loadLiveCount() async {
        guard let races, let list = try? await races.races(), !list.isEmpty else { return }
        let lead = list.first { $0.office == .president } ?? list[0]
        liveCount = LiveCount(counted: lead.sections.percent / 100, races: list.count)
    }
}

extension SearchToken {
    var place: Place? {
        if case .place(let place) = self { return place }
        return nil
    }
}
