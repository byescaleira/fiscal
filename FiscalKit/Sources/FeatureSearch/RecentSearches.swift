import Foundation

public protocol RecentSearchStore: Sendable {
    func load() -> [String]
    func save(_ searches: [String])
}

public struct DeviceRecentSearches: RecentSearchStore {
    public static let key = "fiscal.search.recent"
    public static let legacyKey = "search.recent"
    private let suiteName: String?

    public init(suiteName: String? = nil) {
        self.suiteName = suiteName
    }

    public func load() -> [String] {
        DeviceDefaults.migrated(suiteName, from: Self.legacyKey, to: Self.key)
            .stringArray(forKey: Self.key) ?? []
    }

    public func save(_ searches: [String]) {
        let defaults = DeviceDefaults.migrated(suiteName, from: Self.legacyKey, to: Self.key)
        if searches.isEmpty {
            defaults.removeObject(forKey: Self.key)
        } else {
            defaults.set(searches, forKey: Self.key)
        }
    }
}

enum DeviceDefaults {
    static func migrated(_ suiteName: String?, from legacyKey: String, to key: String)
        -> UserDefaults
    {
        let defaults = suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
        if defaults.object(forKey: key) == nil, let old = defaults.object(forKey: legacyKey) {
            defaults.set(old, forKey: key)
        }
        defaults.removeObject(forKey: legacyKey)
        return defaults
    }
}

enum RecentSearches {
    static let limit = 6

    static func adding(_ query: String, to searches: [String]) -> [String] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 2 else { return searches }
        let key = text.searchFolded
        let rest = searches.filter { $0.searchFolded != key }
        return Array(([text] + rest).prefix(limit))
    }
}
