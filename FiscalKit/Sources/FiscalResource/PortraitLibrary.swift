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
    private let packed: Data?
    private let offsets: [String: [Int]]

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
        packed = nil
        offsets = [:]
    }

    init(
        rigVersion: Int, entries: [Entry], packed: Data, offsets: [String: [Int]],
        generic: Data?, seal: Data?
    ) {
        self.rigVersion = rigVersion
        self.entries = Dictionary(
            entries.map { ($0.slug, $0) }, uniquingKeysWith: { first, _ in first })
        animations = [:]
        self.packed = packed
        self.offsets = offsets
        self.generic = generic
        self.seal = seal
    }

    public static let empty = PortraitLibrary(rigVersion: 0, entries: [], animations: [:])

    public static let bundled: PortraitLibrary = {
        guard let url = Bundle.module.url(forResource: "fiscal-portraits", withExtension: "pack"),
            let data = try? Data(contentsOf: url, options: .alwaysMapped),
            let library = try? unpack(data)
        else { return .empty }
        return library
    }()

    public static func unpack(_ data: Data) throws -> PortraitLibrary {
        guard data.count > 4 else { throw PortraitLibraryError.malformed }
        let length = data.prefix(4).reduce(0) { $0 << 8 | Int($1) }
        let start = data.startIndex + 4
        guard data.count >= 4 + length,
            let root = try JSONSerialization.jsonObject(with: data[start..<start + length])
                as? [String: Any],
            let rigVersion = root["rigVersion"] as? Int,
            let people = root["people"] as? [[String: Any]],
            let offsets = root["offsets"] as? [String: [Int]]
        else { throw PortraitLibraryError.malformed }
        let entries = try JSONDecoder().decode(
            [Entry].self, from: JSONSerialization.data(withJSONObject: people))
        return PortraitLibrary(
            rigVersion: rigVersion, entries: entries, packed: data.suffix(from: start + length),
            offsets: offsets, generic: try root["generic"].map(document),
            seal: try root["seal"].map(document))
    }

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
            encoded[entry.slug] = try document(animation)
        }
        return PortraitLibrary(
            rigVersion: rigVersion, entries: entries, animations: encoded,
            generic: try root["generic"].map(document), seal: try root["seal"].map(document))
    }

    private static func document(_ value: Any) throws -> Data {
        if let text = value as? String { return Data(text.utf8) }
        return try JSONSerialization.data(withJSONObject: value)
    }

    public var slugs: [String] {
        entries.keys.sorted()
    }

    public func animationData(for slug: String, party: String) -> Data? {
        guard let entry = entries[slug], Self.sameParty(entry.party, party) else { return nil }
        if let data = animations[slug] { return data }
        guard let packed, let range = offsets[slug], range.count == 2 else { return nil }
        let from = packed.startIndex + range[0]
        let slice = packed[from..<from + range[1]]
        return try? (Data(slice) as NSData).decompressed(using: .zlib) as Data
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
