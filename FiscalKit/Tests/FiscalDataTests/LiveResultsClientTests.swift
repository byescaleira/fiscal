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
    private func client(offline: OfflinePackStore? = nil) -> LiveResultsClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        StubProtocol.requests = []
        return LiveResultsClient(
            dataURL: URL(string: "https://dados.example.test")!,
            session: URLSession(configuration: configuration), offline: offline)
    }

    @Test func withTheCDNDownTheRacesComeFromThePackAndNoOtherAddress() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "LiveResultsPack-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let pack = OfflinePackStore(directory: directory)
        try await pack.write(
            Data(#"{"races":[],"fetchedAt":"2026-10-25T19:50:00Z"}"#.utf8), etag: nil,
            for: "races.json")
        let client = client(offline: pack)
        StubProtocol.status = 503
        #expect(try await client.races().isEmpty)
        #expect(StubProtocol.requests.map(\.path) == ["/v2/races.json"])
        StubProtocol.status = 200
    }

    @Test func readsTheRaceListFromTheCDN() async throws {
        let client = client()
        StubProtocol.status = 200
        StubProtocol.body = Data(#"{"races":[],"fetchedAt":"2026-10-25T20:00:00Z"}"#.utf8)
        #expect(try await client.races().isEmpty)
        #expect(StubProtocol.requests.map(\.path) == ["/v2/races.json"])
    }

    @Test func keepsAnOldListFromTheCDNAndCallsNoOtherAddress() async throws {
        let client = client()
        StubProtocol.status = 200
        StubProtocol.body = Data(
            #"{"races":[],"fetchedAt":"2020-10-25T20:00:00Z"}"#.utf8)
        #expect(try await client.races().isEmpty)
        #expect(StubProtocol.requests.count == 1)
    }

    @Test func separatesRejectionsFromOutages() async {
        let client = client()
        StubProtocol.status = 403
        await #expect(throws: LiveResultsError.rejected(403)) { try await client.races() }
        StubProtocol.status = 503
        await #expect(throws: LiveResultsError.unavailable) { try await client.races() }
        #expect(StubProtocol.requests.allSatisfy { $0.path == "/v2/races.json" })
    }
}
