import Foundation

public struct PortraitLibrary: Sendable {
    public struct Entry: Codable, Sendable, Hashable {
        public let slug: String
        public let party: String
        public let updatedAt: String

        public init(slug: String, party: String, updatedAt: String) {
            self.slug = slug
            self.party = party
            self.updatedAt = updatedAt
        }
    }

    public let rigVersion: Int
    public let entries: [String: Entry]
    public let generic: Data?
    public let seal: Data?
    private let animations: [String: Data]

    public init(
        rigVersion: Int, entries: [Entry], animations: [String: Data], generic: Data? = nil,
        seal: Data? = nil
    ) {
        self.rigVersion = rigVersion
        self.entries = Dictionary(
            entries.map { ($0.slug, $0) }, uniquingKeysWith: { first, _ in first })
        self.animations = animations
        self.generic = generic
        self.seal = seal
    }

    public static let empty = PortraitLibrary(rigVersion: 0, entries: [], animations: [:])

    public static let bundled: PortraitLibrary = {
        guard let url = Bundle.module.url(forResource: "fiscal-portraits", withExtension: "json"),
            let data = try? Data(contentsOf: url), let library = try? decode(data)
        else { return .empty }
        return library
    }()

    public static func decode(_ data: Data) throws -> PortraitLibrary {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let rigVersion = root["rigVersion"] as? Int,
            let people = root["people"] as? [[String: Any]],
            let animations = root["animations"] as? [String: Any]
        else { throw PortraitLibraryError.malformed }
        let entries = try JSONDecoder().decode(
            [Entry].self, from: JSONSerialization.data(withJSONObject: people))
        var encoded: [String: Data] = [:]
        for entry in entries {
            guard let animation = animations[entry.slug] else {
                throw PortraitLibraryError.missingAnimation(entry.slug)
            }
            encoded[entry.slug] = try JSONSerialization.data(withJSONObject: animation)
        }
        return PortraitLibrary(
            rigVersion: rigVersion, entries: entries, animations: encoded,
            generic: try root["generic"].map { try JSONSerialization.data(withJSONObject: $0) },
            seal: try root["seal"].map { try JSONSerialization.data(withJSONObject: $0) })
    }

    public var slugs: [String] {
        entries.keys.sorted()
    }

    public func animationData(for slug: String, party: String) -> Data? {
        guard let entry = entries[slug], Self.sameParty(entry.party, party) else { return nil }
        return animations[slug]
    }

    public static func sameParty(_ first: String, _ second: String) -> Bool {
        partyKey(first) == partyKey(second)
    }

    public static func partyKey(_ party: String) -> String {
        party.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .replacingOccurrences(of: " ", with: "")
    }

    public static func remotePath(for slug: String) -> String {
        "avatars/\(slug).json"
    }

    public static let remoteIndexPath = "avatars/index.json"
}

public enum PortraitLibraryError: Error, Equatable {
    case malformed
    case missingAnimation(String)
}
