import FiscalDomain
import Foundation

public struct LiveResultsClient: LiveResultsService {
    private struct Registration: Encodable {
        let raceId: String
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
        guard let value = bundle.object(forInfoDictionaryKey: "FiscalAPIURL") as? String,
            let url = URL(string: value), !value.isEmpty
        else { return nil }
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
        var request = URLRequest(url: baseURL.appending(path: "v1/live-activities/\(pushToken)"))
        request.httpMethod = "DELETE"
        request.timeoutInterval = 15
        let (_, response) = try await session.data(for: request)
        try Self.check(response)
    }

    private static func check(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw FiscalError.onFetch
        }
    }
}
