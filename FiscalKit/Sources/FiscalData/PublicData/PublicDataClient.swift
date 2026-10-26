import FiscalDomain
import Foundation

public struct PublicDataClient: PublicDataService {
    static let offlineCodes: Set<URLError.Code> = [
        .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed,
        .internationalRoamingOff, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed,
        .timedOut,
    ]

    public static let sharedSession = makeSession(
        cache: URLCache(
            memoryCapacity: 8 * 1_024 * 1_024, diskCapacity: 128 * 1_024 * 1_024,
            directory: URLCache.publicDataDirectory))

    private let baseURL: URL
    private let dataURL: URL?
    private let session: URLSession
    private let offline: OfflinePackStore?
    private let notice: OfflineNotice?

    public init(
        baseURL: URL, dataURL: URL? = nil, session: URLSession = PublicDataClient.sharedSession,
        offline: OfflinePackStore? = nil, notice: OfflineNotice? = nil
    ) {
        self.baseURL = baseURL
        self.dataURL = dataURL
        self.session = session
        self.offline = offline
        self.notice = notice
    }

    public static func makeSession(cache: URLCache) -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = cache
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }

    public static func fromBundle(_ bundle: Bundle = .main) -> PublicDataClient? {
        var value = bundle.object(forInfoDictionaryKey: "FiscalAPIURL") as? String
        #if DEBUG
            if let override = UserDefaults.standard.string(forKey: "FiscalAPIURL") {
                value = override
            }
        #endif
        guard let value, !value.isEmpty, let url = URL(string: value) else { return nil }
        return PublicDataClient(
            baseURL: url, dataURL: dataURL(bundle), offline: .shared, notice: .shared)
    }

    static func dataURL(_ bundle: Bundle) -> URL? {
        var value = bundle.object(forInfoDictionaryKey: "FiscalDataURL") as? String
        #if DEBUG
            if let override = UserDefaults.standard.string(forKey: "FiscalDataURL") {
                value = override
            }
        #endif
        guard let value, !value.isEmpty else { return nil }
        return URL(string: value)
    }

    public func url(for path: String) -> URL {
        baseURL.appending(path: "v1").appending(path: path)
    }

    func layoutURL(for path: String, base: URL) -> URL {
        base.appending(path: PublicDataLayout.version).appending(path: path)
    }

    public func meta() async throws -> PublicMeta { try await get(PublicDataPath.meta) }

    public func people() async throws -> [PersonCard] { try await get(PublicDataPath.people) }

    public func places() async throws -> [Place] { try await get(PublicDataPath.places) }

    public func representatives(uf: String) async throws -> PlaceRepresentatives {
        try await get(PublicDataPath.representatives(uf: uf))
    }

    public func cityRepresentatives(code: String) async throws -> PlaceRepresentatives? {
        do {
            return try await get(PublicDataPath.cityRepresentatives(code: code))
        } catch PublicDataError.notFound {
            return nil
        }
    }

    public func profile(slug: String) async throws -> Profile {
        try await get(PublicDataPath.profile(slug: slug))
    }

    public func votes(slug: String, year: Int) async throws -> PublicList<PersonVote> {
        try await get(PublicDataPath.votes(slug: slug, year: year))
    }

    public func proposals(slug: String, year: Int) async throws -> PublicList<Proposal> {
        try await get(PublicDataPath.proposals(slug: slug, year: year))
    }

    public func speeches(slug: String, year: Int) async throws -> PublicList<Speech> {
        try await get(PublicDataPath.speeches(slug: slug, year: year))
    }

    public func expenses(slug: String, year: Int) async throws -> ExpenseList {
        try await get(PublicDataPath.expenses(slug: slug, year: year))
    }

    public func checks(slug: String) async throws -> FactCheckList? {
        do {
            return try await get(PublicDataPath.checks(slug: slug))
        } catch PublicDataError.notFound {
            return nil
        }
    }

    public func recentVotes() async throws -> [VoteSummary] {
        try await get(PublicDataPath.recentVotes)
    }

    public func vote(id: String) async throws -> VoteDetail {
        try await get(PublicDataPath.vote(id: id))
    }

    public func agenda() async throws -> Agenda { try await get(PublicDataPath.agenda) }

    public func money() async throws -> MoneyOverview { try await get(PublicDataPath.money) }

    public func mandateCost() async throws -> MandateCost? {
        try await optional(PublicDataPath.mandateCost)
    }

    public func moneyPlaces() async throws -> MoneyPlaces? {
        try await optional(PublicDataPath.moneyPlaces)
    }

    public func today() async throws -> TodayDigest { try await get(PublicDataPath.today) }

    public func actions(slug: String) async throws -> ActionList? {
        try await optional(PublicDataPath.actions(slug: slug))
    }

    public func highlights() async throws -> HighlightList? {
        try await optional(PublicDataPath.highlights)
    }

    public func weightMethod() async throws -> WeightMethod? {
        try await optional(PublicDataPath.weightMethod)
    }

    public func indicators() async throws -> IndicatorCatalog? {
        try await optional(PublicDataPath.indicators)
    }

    public func indicator(id: String) async throws -> Indicator? {
        try await optional(PublicDataPath.indicator(id: id))
    }

    public func context(slug: String) async throws -> PersonContext? {
        try await optional(PublicDataPath.context(slug: slug))
    }

    public func facts() async throws -> FactIndex? {
        try await optional(PublicDataPath.facts)
    }

    public func electionHistory() async throws -> ElectionHistory? {
        try await optional(HistoryPath.elections)
    }

    public func pastRace(id: String) async throws -> PastRace? {
        try await optional(HistoryPath.race(id: id))
    }

    public func politicalTimeline() async throws -> PoliticalTimeline? {
        try await optional(HistoryPath.periods)
    }

    public func studyCatalog() async throws -> StudyCatalog? {
        try await optional(HistoryPath.study)
    }

    func optional<Value: Decodable>(_ path: String) async throws -> Value? {
        do {
            return try await get(path)
        } catch PublicDataError.notFound {
            return nil
        }
    }

    func get<Value: Decodable>(_ path: String) async throws -> Value {
        do {
            return try await online(path)
        } catch let error as PublicDataError where error == .offline || error == .unavailable {
            guard let offline, let value: Value = try await packed(path, from: offline) else {
                throw error
            }
            return value
        }
    }

    private func online<Value: Decodable>(_ path: String) async throws -> Value {
        if let dataURL, await PublicDataRoute.shared.isLive(dataURL, session: session) {
            do {
                return try await PublicDataResolver { try await fetch($0, base: dataURL) }
                    .value(path)
            } catch PublicDataError.unavailable {
                return try await legacy(path)
            }
        }
        return try await legacy(path)
    }

    private func packed<Value: Decodable>(_ path: String, from store: OfflinePackStore)
        async throws -> Value?
    {
        let resolver = PublicDataResolver(isPack: true) { file in
            guard let data = await store.data(for: file) else { throw PublicDataError.offline }
            return data
        }
        do {
            let value: Value = try await resolver.value(path)
            notice?.markOffline(dataFrom: await store.updatedAt)
            return value
        } catch PublicDataError.offline {
            return nil
        }
    }

    private func legacy<Value: Decodable>(_ path: String) async throws -> Value {
        let data = try await load(Self.request(url(for: path)))
        return try PublicDataResolver.decode(data, keys: [])
    }

    private func fetch(_ file: String, base: URL) async throws -> Data {
        let url = layoutURL(for: file, base: base)
        if let recent = await PublicDataRecent.shared.data(for: url) { return recent }
        let data = try await load(Self.request(url))
        await PublicDataRecent.shared.store(data, for: url)
        return data
    }

    private static func request(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 20
        return request
    }

    private func load(_ request: URLRequest) async throws -> Data {
        let cache = session.configuration.urlCache
        let cached = cache?.cachedResponse(for: request)
        var conditional = request
        conditional.cachePolicy = .reloadIgnoringLocalCacheData
        if let tag = (cached?.response as? HTTPURLResponse)?.value(forHTTPHeaderField: "ETag") {
            conditional.setValue(tag, forHTTPHeaderField: "If-None-Match")
        }
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: conditional)
        } catch let error as URLError {
            if error.code == .cancelled { throw CancellationError() }
            let offline = Self.offlineCodes.contains(error.code)
            if let cached {
                if offline { notice?.markOffline(dataFrom: Self.date(of: cached)) }
                return cached.data
            }
            throw offline ? PublicDataError.offline : PublicDataError.unavailable
        }
        guard let http = response as? HTTPURLResponse else { throw PublicDataError.unavailable }
        switch http.statusCode {
        case 200..<300:
            cache?.storeCachedResponse(CachedURLResponse(response: http, data: data), for: request)
            notice?.markOnline()
            return data
        case 304:
            guard let cached else { throw PublicDataError.unavailable }
            notice?.markOnline()
            return cached.data
        case 404, 410:
            throw PublicDataError.notFound
        case 400..<500 where http.statusCode != 429:
            throw PublicDataError.rejected(http.statusCode)
        default:
            if let cached { return cached.data }
            throw PublicDataError.unavailable
        }
    }
}

extension PublicDataClient {
    static func date(of cached: CachedURLResponse) -> Date? {
        guard let value = (cached.response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Date")
        else { return nil }
        return try? Date(value, strategy: Date.HTTPFormatStyle())
    }
}

extension URLCache {
    public static var publicDataDirectory: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appending(path: "PublicData", directoryHint: .isDirectory)
    }
}
