import FiscalDomain
import Foundation

public struct LiveResultsClient: LiveResultsService, HighlightAlertService {
    private struct Removal: Encodable {
        let pushToken: String
        let challenge: String?
    }

    private struct Registration: Encodable {
        let raceId: String
        let pushToken: String
        let environment: PushEnvironment
        let challenge: String?
    }

    private struct HighlightRegistration: Encodable {
        let pushToken: String
        let environment: PushEnvironment
        let challenge: String?
    }

    private let baseURL: URL
    private let dataURL: URL?
    private let session: URLSession
    private let offline: OfflinePackStore?

    public init(
        baseURL: URL, dataURL: URL? = nil, session: URLSession = .shared,
        offline: OfflinePackStore? = nil
    ) {
        self.baseURL = baseURL
        self.dataURL = dataURL
        self.session = session
        self.offline = offline
    }

    public static func fromBundle(_ bundle: Bundle = .main) -> LiveResultsClient? {
        var value = bundle.object(forInfoDictionaryKey: "FiscalAPIURL") as? String
        #if DEBUG
            if let override = UserDefaults.standard.string(forKey: "FiscalAPIURL") {
                value = override
            }
        #endif
        guard let value, !value.isEmpty, let url = URL(string: value) else { return nil }
        return LiveResultsClient(
            baseURL: url, dataURL: PublicDataClient.dataURL(bundle), offline: .shared)
    }

    public func races() async throws -> [Race] {
        if let dataURL,
            let list = try? await raceList(
                at: dataURL.appending(path: PublicDataLayout.version).appending(path: "races.json")),
            Self.isCurrent(list, now: Date())
        {
            if offline != nil { OfflineNotice.shared.markOnline() }
            return list.races
        }
        do {
            return try await raceList(at: baseURL.appending(path: "v1/races")).races
        } catch {
            guard let offline, let data = await offline.data(for: "races.json"),
                let list = try? JSONDecoder().decode(RaceList.self, from: data)
            else { throw error }
            OfflineNotice.shared.markOffline(dataFrom: await offline.updatedAt)
            return list.races
        }
    }

    private func raceList(at url: URL) async throws -> RaceList {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15
        let (data, response) = try await session.data(for: request)
        try Self.check(response)
        return try JSONDecoder().decode(RaceList.self, from: data)
    }

    static let liveFreshness: TimeInterval = 300

    static func isCurrent(_ list: RaceList, now: Date) -> Bool {
        guard list.races.contains(where: { !$0.final && $0.hasStarted }) else { return true }
        guard let fetched = try? Date(list.fetchedAt, strategy: .iso8601) else { return false }
        return now.timeIntervalSince(fetched) <= liveFreshness
    }

    public func follow(raceID: String, pushToken: String, environment: PushEnvironment)
        async throws
    {
        try await attested(path: "v1/live-activities") { challenge in
            Registration(
                raceId: raceID, pushToken: pushToken, environment: environment,
                challenge: challenge)
        }
    }

    public func unfollow(pushToken: String) async throws {
        try await attested(method: "DELETE", path: "v1/live-activities") { challenge in
            Removal(pushToken: pushToken, challenge: challenge)
        }
    }

    public func registerHighlights(pushToken: String, environment: PushEnvironment)
        async throws
    {
        try await attested(path: "v1/highlight-activities") { challenge in
            HighlightRegistration(
                pushToken: pushToken, environment: environment, challenge: challenge)
        }
    }

    public func unregisterHighlights(pushToken: String) async throws {
        try await attested(method: "DELETE", path: "v1/highlight-activities") { challenge in
            Removal(pushToken: pushToken, challenge: challenge)
        }
    }

    private func send(_ method: String, path: String, body: some Encodable) async throws {
        let (_, response) = try await raw(
            method, path: path, body: try JSONEncoder().encode(body), headers: [:])
        try Self.check(response)
    }

    private func attested<Body: Encodable>(
        method: String = "POST", path: String, body make: (String?) -> Body, retry: Bool = true
    ) async throws {
        let attestor = AppAttestor.shared
        if let prepared = await attestor.prepare(base: baseURL, session: session) {
            let body = try JSONEncoder().encode(make(prepared.challenge))
            if let assertion = await attestor.assertion(keyID: prepared.keyID, body: body) {
                let (data, response) = try await raw(
                    method, path: path, body: body,
                    headers: [
                        "X-Fiscal-Attest-Key": prepared.keyID,
                        "X-Fiscal-Attest-Assertion": assertion,
                    ])
                if retry, (response as? HTTPURLResponse)?.statusCode == 401,
                    Self.code(data) == "attest_unknown_key"
                {
                    await attestor.forget()
                    try await attested(method: method, path: path, body: make, retry: false)
                    return
                }
                try Self.check(response)
                return
            }
        }
        try await send(method, path: path, body: make(nil))
    }

    private func raw(_ method: String, path: String, body: Data, headers: [String: String])
        async throws -> (Data, URLResponse)
    {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }
        request.timeoutInterval = 15
        request.httpBody = body
        return try await session.data(for: request)
    }

    private static func code(_ data: Data) -> String? {
        struct Failure: Decodable {
            struct Detail: Decodable { let code: String }
            let error: Detail
        }
        return (try? JSONDecoder().decode(Failure.self, from: data))?.error.code
    }

    private static func check(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw LiveResultsError.unavailable }
        switch http.statusCode {
        case 200..<300: return
        case 400..<500 where http.statusCode != 429:
            throw LiveResultsError.rejected(http.statusCode)
        default: throw LiveResultsError.unavailable
        }
    }
}
