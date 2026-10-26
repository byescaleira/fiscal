import Foundation

public struct PortraitLibrary: Sendable {
    public struct Traits: Sendable, Hashable {
        public let slug: String
        public let values: [String: String]

        public init(slug: String, values: [String: String]) {
            self.slug = slug
            self.values = values
        }

        public var party: String { values["party"] ?? "" }

        public subscript(field: String) -> String? { values[field] }
    }

    public let rigVersion: Int
    public let people: [String: Traits]
    public let rig: Data?
    public let seal: Data?

    public init(rigVersion: Int, people: [Traits], rig: Data? = nil, seal: Data? = nil) {
        self.rigVersion = rigVersion
        self.people = Dictionary(
            people.map { ($0.slug, $0) }, uniquingKeysWith: { first, _ in first })
        self.rig = rig
        self.seal = seal
    }

    public static let empty = PortraitLibrary(rigVersion: 0, people: [])

    public static let bundled: PortraitLibrary = {
        guard let traits = resource("fiscal-portrait-traits"),
            let library = try? decode(
                traits: traits, rig: resource("fiscal-portrait-rig"),
                seal: resource("fiscal-party-seal"))
        else { return .empty }
        return library
    }()

    private static func resource(_ name: String) -> Data? {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json") else {
            return nil
        }
        return try? Data(contentsOf: url, options: .alwaysMapped)
    }

    public static func decode(traits: Data, rig: Data?, seal: Data?) throws -> PortraitLibrary {
        guard let root = try JSONSerialization.jsonObject(with: traits) as? [String: Any],
            let rigVersion = root["rigVersion"] as? Int,
            let fields = root["fields"] as? [String], fields.first == "slug",
            let values = root["values"] as? [String: [String]],
            let rows = root["people"] as? [[Any]]
        else { throw PortraitLibraryError.malformed }
        let people = try rows.map { row in
            guard row.count == fields.count, let slug = row.first as? String else {
                throw PortraitLibraryError.malformed
            }
            var traits: [String: String] = [:]
            for (field, cell) in zip(fields, row).dropFirst() {
                guard let index = cell as? Int, let options = values[field],
                    options.indices.contains(index)
                else { throw PortraitLibraryError.malformed }
                if !options[index].isEmpty { traits[field] = options[index] }
            }
            return Traits(slug: slug, values: traits)
        }
        return PortraitLibrary(rigVersion: rigVersion, people: people, rig: rig, seal: seal)
    }

    public var slugs: [String] {
        people.keys.sorted()
    }

    public func traits(for slug: String, party: String) -> Traits? {
        guard let traits = people[slug], Self.sameParty(traits.party, party) else { return nil }
        return traits
    }

    public static func sameParty(_ first: String, _ second: String) -> Bool {
        partyKey(first) == partyKey(second)
    }

    public static func partyKey(_ party: String) -> String {
        party.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
    }

    public static let remoteRigPath = "avatars/rig.json"
    public static let remoteTraitsPath = "avatars/traits.json"
}

public enum PortraitLibraryError: Error, Equatable {
    case malformed
}
