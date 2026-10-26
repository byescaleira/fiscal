import FiscalDomain
import Foundation

public struct LiveResultsClient: LiveResultsService, HighlightAlertService {
    private struct Removal: Encodable {
        let pushToken: String
    }

    private struct Registration: Encodable {
        let raceId: String
        let pushToken: String
        let environment: PushEnvironment
    }

    private struct HighlightRegistration: Encodable {
        let pushToken: String
        let environment: PushEnvironment
    }

    private let baseURL: URL
    private let session: URLSession

    public init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    public static func fromBundle(_ bundle: Bundle = .main) -> LiveResultsClient? {
        var value = bundle.object(forInfoDictionaryKey: "FiscalAPIURL") as? String
        #if DEBUG
            if let override = UserDefaults.standard.string(forKey: "FiscalAPIURL") {
                value = override
            }
        #endif
        guard let value, !value.isEmpty, let url = URL(string: value) else { return nil }
        return LiveResultsClient(baseURL: url)
    }

    public func races() async throws -> [Race] {
        var request = URLRequest(url: baseURL.appending(path: "v1/races"))
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15
        let (data, response) = try await session.data(for: request)
        try Self.check(response)
        return try JSONDecoder().decode(RaceList.self, from: data).races
    }

    public func follow(raceID: String, pushToken: String, environment: PushEnvironment)
        async throws
    {
        var request = URLRequest(url: baseURL.appending(path: "v1/live-activities"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15
        request.httpBody = try JSONEncoder().encode(
            Registration(raceId: raceID, pushToken: pushToken, environment: environment))
        let (_, response) = try await session.data(for: request)
        try Self.check(response)
    }

    public func unfollow(pushToken: String) async throws {
        try await send("DELETE", path: "v1/live-activities", body: Removal(pushToken: pushToken))
    }

    public func registerHighlights(pushToken: String, environment: PushEnvironment)
        async throws
    {
        try await send(
            "POST", path: "v1/highlight-activities",
            body: HighlightRegistration(pushToken: pushToken, environment: environment))
    }

    public func unregisterHighlights(pushToken: String) async throws {
        try await send(
            "DELETE", path: "v1/highlight-activities", body: Removal(pushToken: pushToken))
    }

    private func send(_ method: String, path: String, body: some Encodable) async throws {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15
        request.httpBody = try JSONEncoder().encode(body)
        let (_, response) = try await session.data(for: request)
        try Self.check(response)
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
