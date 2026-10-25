import FiscalDomain
import Foundation

public struct PublicDataClient: PublicDataService {
    private static let offlineCodes: Set<URLError.Code> = [
        .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed,
        .internationalRoamingOff, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed,
        .timedOut,
    ]

    public static let sharedSession = makeSession(
        cache: URLCache(
            memoryCapacity: 8 * 1_024 * 1_024, diskCapacity: 128 * 1_024 * 1_024,
            directory: URLCache.publicDataDirectory))

    private let baseURL: URL
    private let session: URLSession

    public init(baseURL: URL, session: URLSession = PublicDataClient.sharedSession) {
        self.baseURL = baseURL
        self.session = session
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
        return PublicDataClient(baseURL: url)
    }

    public func url(for path: String) -> URL {
        baseURL.appending(path: "v1").appending(path: path)
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

    func optional<Value: Decodable>(_ path: String) async throws -> Value? {
        do {
            return try await get(path)
        } catch PublicDataError.notFound {
            return nil
        }
    }

    func get<Value: Decodable>(_ path: String) async throws -> Value {
        var request = URLRequest(url: url(for: path))
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 20
        let data = try await load(request)
        do {
            return try PublicDataCoding.decoder().decode(Value.self, from: data)
        } catch {
            throw PublicDataError.invalidData
        }
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
            if let cached { return cached.data }
            throw Self.offlineCodes.contains(error.code)
                ? PublicDataError.offline : PublicDataError.unavailable
        }
        guard let http = response as? HTTPURLResponse else { throw PublicDataError.unavailable }
        switch http.statusCode {
        case 200..<300:
            cache?.storeCachedResponse(CachedURLResponse(response: http, data: data), for: request)
            return data
        case 304:
            guard let cached else { throw PublicDataError.unavailable }
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

extension URLCache {
    public static var publicDataDirectory: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appending(path: "PublicData", directoryHint: .isDirectory)
    }
}
