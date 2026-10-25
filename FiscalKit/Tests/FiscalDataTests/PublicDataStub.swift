import Foundation
import Synchronization

final class PublicDataStub: URLProtocol, @unchecked Sendable {
    struct Reply: Sendable {
        var status = 200
        var body = Data()
        var headers: [String: String] = [:]
        var failure: URLError.Code?
    }

    struct Seen: Sendable {
        let path: String
        let ifNoneMatch: String?
    }

    private struct Host: Sendable {
        var replies: [String: Reply] = [:]
        var fallback = Reply(status: 404)
        var seen: [Seen] = []
    }

    private static let hosts = Mutex<[String: Host]>([:])

    static func makeHost() -> String {
        let host = "\(UUID().uuidString.lowercased()).example.test"
        hosts.withLock { $0[host] = Host() }
        return host
    }

    static func reply(_ reply: Reply, to path: String, on host: String) {
        hosts.withLock { $0[host, default: Host()].replies[path] = reply }
    }

    static func fallback(_ reply: Reply, on host: String) {
        hosts.withLock { $0[host, default: Host()].fallback = reply }
    }

    static func seen(on host: String) -> [Seen] {
        hosts.withLock { $0[host]?.seen ?? [] }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, let host = url.host() else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let path = url.path()
        let reply = Self.hosts.withLock { hosts -> Reply in
            hosts[host, default: Host()].seen.append(
                Seen(path: path, ifNoneMatch: request.value(forHTTPHeaderField: "If-None-Match")))
            return hosts[host]?.replies[path] ?? hosts[host]?.fallback ?? Reply(status: 404)
        }
        if let failure = reply.failure {
            client?.urlProtocol(self, didFailWithError: URLError(failure))
            return
        }
        guard
            let response = HTTPURLResponse(
                url: url, statusCode: reply.status, httpVersion: "HTTP/1.1",
                headerFields: reply.headers)
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: reply.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
