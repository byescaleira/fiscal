import CryptoKit
import FiscalDomain
import Foundation

enum PublicDataLayout {
    static let version = "v2"
    static let cityPeopleIndex = Family(directory: "index/city-people", count: 256)
    static let voteBundles = Family(directory: "votes/by-id", count: 512)

    struct Family: Equatable {
        let directory: String
        let count: Int

        func bucket(_ key: String) -> String {
            let digest = Array(SHA256.hash(data: Data(key.utf8)))
            let value = (Int(digest[0]) << 8 | Int(digest[1])) % count
            let width = String(count - 1, radix: 16).count
            let hex = String(value, radix: 16)
            return String(repeating: "0", count: max(width - hex.count, 0)) + hex
        }

        func path(_ key: String) -> String { "\(directory)/\(bucket(key)).json" }
    }

    enum Location: Equatable {
        case file(String)
        case member(String, [String])
        case profile(String)
    }

    static func locate(_ path: String) -> Location {
        let parts = path.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard let last = parts.last, last.hasSuffix(".json") else { return .file(path) }
        let name = String(last.dropLast(5))
        switch (parts.first, parts.count) {
        case ("people", 2):
            return .profile(name)
        case ("people", 3):
            return .member("people/\(parts[1]).json", ["files", last])
        case ("places", 3) where parts[1] == "city":
            return .member(path, ["place"])
        case ("votes", 2) where name != "recent":
            return .member(voteBundles.path(name), ["items", name])
        default:
            return .file(path)
        }
    }
}

struct AnyCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int? = nil

    init(_ string: String) { stringValue = string }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}

extension CodingUserInfoKey {
    static let publicDataMember = CodingUserInfoKey(rawValue: "publicDataMember").unsafelyUnwrapped
}

struct PublicDataMember<Value: Decodable>: Decodable {
    let value: Value?

    init(from decoder: any Decoder) throws {
        let keys = decoder.userInfo[.publicDataMember] as? [String] ?? []
        guard let last = keys.last else {
            value = try Value(from: decoder)
            return
        }
        var container = try decoder.container(keyedBy: AnyCodingKey.self)
        for key in keys.dropLast() {
            guard container.contains(AnyCodingKey(key)),
                (try? container.decodeNil(forKey: AnyCodingKey(key))) == false
            else {
                value = nil
                return
            }
            container = try container.nestedContainer(
                keyedBy: AnyCodingKey.self, forKey: AnyCodingKey(key))
        }
        value = try container.decodeIfPresent(Value.self, forKey: AnyCodingKey(last))
    }

    static func decode(_ data: Data, keys: [String]) throws -> Value? {
        let decoder = PublicDataCoding.decoder()
        decoder.userInfo[.publicDataMember] = keys
        return try decoder.decode(Self.self, from: data).value
    }
}

struct PublicDataOrigin: Decodable, Equatable {
    let first: [String]
    let onMissing: [String]

    func readsFirst(_ path: String) -> Bool { first.contains(path) }

    func coversMissing(_ path: String) -> Bool { onMissing.contains { path.hasPrefix($0) } }
}

actor PublicDataRoute {
    static let shared = PublicDataRoute()

    private struct Release: Decodable {
        let release: String
        let layout: String
        let origin: PublicDataOrigin?
    }

    private struct Entry {
        let live: Bool
        let origin: PublicDataOrigin?
        let at: Date
    }

    private var known: [URL: Entry] = [:]
    private let defaultsKey = "PublicDataLayoutLive"

    func isLive(_ base: URL, session: URLSession) async -> Bool {
        await route(base, session: session).live
    }

    func origin(_ base: URL, session: URLSession) async -> PublicDataOrigin? {
        await route(base, session: session).origin
    }

    private func route(_ base: URL, session: URLSession) async -> (
        live: Bool, origin: PublicDataOrigin?
    ) {
        if let entry = known[base], Date().timeIntervalSince(entry.at) < (entry.live ? 600 : 120) {
            return (entry.live, entry.origin)
        }
        var request = URLRequest(
            url: base.appending(path: PublicDataLayout.version).appending(path: "release.json"))
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 8
        do {
            let (data, response) = try await session.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let release = try? JSONDecoder().decode(Release.self, from: data)
            let live = status == 200 && release?.layout == PublicDataLayout.version
            let origin = live ? release?.origin : nil
            remember(base, live, origin)
            return (live, origin)
        } catch {
            if let entry = known[base] { return (entry.live, entry.origin) }
            return (UserDefaults.standard.bool(forKey: defaultsKey), nil)
        }
    }

    func forget() { known = [:] }

    private func remember(_ base: URL, _ live: Bool, _ origin: PublicDataOrigin?) {
        known[base] = Entry(live: live, origin: origin, at: Date())
        UserDefaults.standard.set(live, forKey: defaultsKey)
    }
}

actor PublicDataRecent {
    static let shared = PublicDataRecent()

    private var entries: [URL: (data: Data, at: Date)] = [:]
    private let lifetime: TimeInterval = 30
    private let limit = 12

    func data(for url: URL) -> Data? {
        guard let entry = entries[url], Date().timeIntervalSince(entry.at) < lifetime else {
            return nil
        }
        return entry.data
    }

    func store(_ data: Data, for url: URL) {
        if entries.count >= limit,
            let oldest = entries.min(by: { $0.value.at < $1.value.at })?.key
        {
            entries[oldest] = nil
        }
        entries[url] = (data, Date())
    }
}
