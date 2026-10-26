import FiscalDomain
import Foundation
import Testing

@testable import FiscalData

private final class StubProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var status = 200
    nonisolated(unsafe) static var body = Data()
    nonisolated(unsafe) static var requests: [(method: String, path: String, body: Data?)] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        var body = request.httpBody
        if body == nil, let stream = request.httpBodyStream {
            stream.open()
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                data.append(buffer, count: count)
            }
            stream.close()
            body = data
        }
        Self.requests.append((request.httpMethod ?? "", request.url?.path ?? "", body))
        guard let url = request.url,
            let response = HTTPURLResponse(
                url: url, statusCode: Self.status, httpVersion: nil, headerFields: nil)
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@Suite(.serialized)
struct LiveResultsClientTests {
    private func client() -> LiveResultsClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        StubProtocol.requests = []
        return LiveResultsClient(
            baseURL: URL(string: "https://example.test/api")!,
            session: URLSession(configuration: configuration))
    }

    @Test func readsTheRaceList() async throws {
        let client = client()
        StubProtocol.status = 200
        StubProtocol.body = Data(#"{"races":[],"fetchedAt":"2026-10-25T20:00:00Z"}"#.utf8)
        #expect(try await client.races().isEmpty)
        #expect(StubProtocol.requests.first?.path == "/api/v1/races")
    }

    @Test func registersWithTheContractKeys() async throws {
        let client = client()
        StubProtocol.status = 204
        StubProtocol.body = Data()
        try await client.follow(
            raceID: "governador-df", pushToken: "abc123", environment: .production)
        let request = try #require(StubProtocol.requests.first)
        #expect(request.method == "POST")
        #expect(request.path == "/api/v1/live-activities")
        let json =
            try JSONSerialization.jsonObject(with: try #require(request.body)) as? [String: String]
        #expect(
            json == ["raceId": "governador-df", "pushToken": "abc123", "environment": "production"])
    }

    @Test func distrustsALiveCountThatStoppedUpdating() throws {
        func list(final: Bool) throws -> RaceList {
            let json = """
                {"races":[{"id":"presidente-br","office":"president","uf":"br","round":2,
                "sections":{"total":100,"counted":25,"percent":25.0},
                "electorate":1000,"turnout":300,
                "votes":{"valid":280,"blank":10,"null":10,"total":300},
                "candidates":[
                {"number":"22","name":"A","party":"PL","votes":150,"percent":53.5,"elected":false},
                {"number":"13","name":"B","party":"PT","votes":130,"percent":46.5,"elected":false}],
                "final":\(final),"sourceGeneratedAt":"2026-10-25T17:42:10-03:00"}],
                "fetchedAt":"2026-10-25T20:42:15Z"}
                """
            return try JSONDecoder().decode(RaceList.self, from: Data(json.utf8))
        }
        let fetched = try Date("2026-10-25T20:42:15Z", strategy: .iso8601)
        let live = try list(final: false)
        #expect(LiveResultsClient.isCurrent(live, now: fetched.addingTimeInterval(60)))
        #expect(!LiveResultsClient.isCurrent(live, now: fetched.addingTimeInterval(600)))
        #expect(
            LiveResultsClient.isCurrent(
                try list(final: true), now: fetched.addingTimeInterval(86_400)))
    }

    @Test func unregistersWithTheTokenInTheBody() async throws {
        let client = client()
        StubProtocol.status = 204
        try await client.unfollow(pushToken: "abc123")
        let request = try #require(StubProtocol.requests.first)
        #expect(request.method == "DELETE")
        #expect(request.path == "/api/v1/live-activities")
        let json =
            try JSONSerialization.jsonObject(with: try #require(request.body)) as? [String: String]
        #expect(json == ["pushToken": "abc123"])
    }

    @Test func separatesRejectionsFromOutages() async {
        let client = client()
        StubProtocol.status = 422
        await #expect(throws: LiveResultsError.rejected(422)) {
            try await client.follow(raceID: "x", pushToken: "y", environment: .development)
        }
        StubProtocol.status = 429
        await #expect(throws: LiveResultsError.unavailable) { try await client.races() }
        StubProtocol.status = 503
        await #expect(throws: LiveResultsError.unavailable) { try await client.races() }
    }
}
