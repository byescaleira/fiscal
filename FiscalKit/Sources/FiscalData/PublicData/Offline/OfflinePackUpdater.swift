import FiscalDomain
import Foundation

public struct OfflinePackUpdater: Sendable {
    struct Release: Decodable {
        let release: String
        let layout: String
    }

    private let dataURL: URL
    private let session: URLSession
    private let store: OfflinePackStore
    private let now: @Sendable () -> Date

    public init(
        dataURL: URL, session: URLSession = OfflinePackUpdater.makeSession(),
        store: OfflinePackStore = .shared, now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.dataURL = dataURL
        self.session = session
        self.store = store
        self.now = now
    }

    public static func fromBundle(_ bundle: Bundle = .main) -> OfflinePackUpdater? {
        PublicDataClient.dataURL(bundle).map { OfflinePackUpdater(dataURL: $0) }
    }

    public static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.waitsForConnectivity = false
        configuration.timeoutIntervalForRequest = 20
        return URLSession(configuration: configuration)
    }

    public func summary() async -> OfflinePackSummary { await store.summary() }

    public func erase() async -> OfflinePackSummary {
        await store.erase()
        return await store.summary()
    }

    @discardableResult
    public func refresh(_ request: OfflinePackRequest) async throws -> OfflinePackSummary {
        let release = try await currentRelease()
        let unchanged = await store.manifest.release == release.release
        var run = Run(
            unchanged: unchanged, known: unchanged ? Set(await store.manifest.missing) : [])
        for path in OfflinePackPlan.baseFiles {
            _ = try await syncIfPublished(path, in: &run, needsData: false)
        }
        var places: [PlaceRepresentatives] = []
        for path in OfflinePackPlan.regionFiles(placeCode: request.placeCode) {
            guard let data = try await syncIfPublished(path, in: &run, needsData: true) else {
                continue
            }
            let keys = path.hasPrefix("places/city/") ? ["place"] : []
            if let place = try? PublicDataMember<PlaceRepresentatives>.decode(data, keys: keys) {
                places.append(place)
            }
        }
        let people = OfflinePackPlan.people(
            for: request, representatives: OfflinePackPlan.representatives(in: places))
        var kept: [String] = []
        for slug in people {
            try Task.checkCancellation()
            let used = await store.manifest.storedBytes(of: run.keep)
            guard used < OfflinePackPlan.byteBudget else { break }
            if try await syncProfile(slug, in: &run) { kept.append(slug) }
        }
        try Task.checkCancellation()
        try await store.commit(
            release: release.release, people: kept, keeping: run.keep, missing: run.missing,
            at: now())
        return await store.summary()
    }

    struct Run {
        let unchanged: Bool
        let known: Set<String>
        var keep: Set<String> = []
        var missing: Set<String> = []
    }

    private func syncProfile(_ slug: String, in run: inout Run) async throws -> Bool {
        do {
            _ = try await sync(PublicDataPath.profile(slug: slug), in: &run, needsData: false)
            return true
        } catch PublicDataError.notFound {
            let index = PublicDataLayout.cityPeopleIndex.path(slug)
            guard let data = try await syncIfPublished(index, in: &run, needsData: true),
                let code = try? PublicDataMember<String>.decode(data, keys: ["items", slug]),
                code.allSatisfy(\.isNumber), !code.isEmpty
            else { return false }
            let city = PublicDataPath.cityRepresentatives(code: code)
            _ = try await syncIfPublished(city, in: &run, needsData: false)
            return run.keep.contains(city)
        } catch PublicDataError.invalidData, PublicDataError.rejected {
            return false
        }
    }

    private func syncIfPublished(_ path: String, in run: inout Run, needsData: Bool)
        async throws -> Data?
    {
        do {
            return try await sync(path, in: &run, needsData: needsData)
        } catch PublicDataError.notFound, PublicDataError.invalidData {
            return nil
        }
    }

    private func sync(_ path: String, in run: inout Run, needsData: Bool) async throws -> Data? {
        try Task.checkCancellation()
        guard OfflinePackStore.isSafe(path) else { throw PublicDataError.invalidData }
        let entry = await store.entry(for: path)
        let present = await store.hasFile(path)
        if run.unchanged, run.known.contains(path) {
            run.missing.insert(path)
            throw PublicDataError.notFound
        }
        if run.unchanged, present {
            if !needsData {
                run.keep.insert(path)
                return nil
            }
            if let stored = await store.data(for: path) {
                run.keep.insert(path)
                return stored
            }
        }
        var request = URLRequest(
            url: dataURL.appending(path: PublicDataLayout.version).appending(path: path))
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let tag = entry?.etag, present {
            request.setValue(tag, forHTTPHeaderField: "If-None-Match")
        }
        let (data, response) = try await load(request)
        switch response.statusCode {
        case 200..<300:
            guard (try? JSONSerialization.jsonObject(with: data)) != nil else {
                throw PublicDataError.invalidData
            }
            try await store.write(data, etag: response.value(forHTTPHeaderField: "ETag"), for: path)
            run.keep.insert(path)
            return data
        case 304:
            run.keep.insert(path)
            return needsData ? await store.data(for: path) : nil
        case 404, 410:
            run.missing.insert(path)
            throw PublicDataError.notFound
        case 400..<500 where response.statusCode != 429:
            throw PublicDataError.rejected(response.statusCode)
        default:
            throw PublicDataError.unavailable
        }
    }

    private func currentRelease() async throws -> Release {
        var request = URLRequest(
            url: dataURL.appending(path: PublicDataLayout.version).appending(path: "release.json"))
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await load(request)
        guard response.statusCode == 200,
            let release = try? JSONDecoder().decode(Release.self, from: data),
            release.layout == PublicDataLayout.version
        else { throw PublicDataError.unavailable }
        return release
    }

    private func load(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw PublicDataError.unavailable
            }
            return (data, http)
        } catch let error as URLError {
            if error.code == .cancelled { throw CancellationError() }
            throw PublicDataClient.offlineCodes.contains(error.code)
                ? PublicDataError.offline : PublicDataError.unavailable
        }
    }
}

public actor OfflinePackCoordinator: OfflinePackService {
    private let updater: OfflinePackUpdater
    private let request: @Sendable () async -> OfflinePackRequest
    private let now: @Sendable () -> Date
    private var running: Task<OfflinePackSummary, any Error>?
    private var lastAttempt: Date?

    public init(
        updater: OfflinePackUpdater, now: @escaping @Sendable () -> Date = { Date() },
        request: @escaping @Sendable () async -> OfflinePackRequest
    ) {
        self.updater = updater
        self.now = now
        self.request = request
    }

    public func summary() async -> OfflinePackSummary { await updater.summary() }

    public func refresh() async throws -> OfflinePackSummary {
        if let running { return try await running.value }
        let updater = updater
        let request = request
        let task = Task { try await updater.refresh(await request()) }
        running = task
        lastAttempt = now()
        defer { running = nil }
        return try await task.value
    }

    public func refreshIfDue(every interval: TimeInterval) async {
        if let lastAttempt, now().timeIntervalSince(lastAttempt) < interval { return }
        _ = try? await refresh()
    }

    public func erase() async -> OfflinePackSummary {
        running?.cancel()
        running = nil
        return await updater.erase()
    }
}
