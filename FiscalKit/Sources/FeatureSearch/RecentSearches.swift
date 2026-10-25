import Foundation

public protocol RecentSearchStore: Sendable {
    func load() -> [String]
    func save(_ searches: [String])
}

public struct DeviceRecentSearches: RecentSearchStore, @unchecked Sendable {
    public static let key = "search.recent"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> [String] {
        defaults.stringArray(forKey: Self.key) ?? []
    }

    public func save(_ searches: [String]) {
        if searches.isEmpty {
            defaults.removeObject(forKey: Self.key)
        } else {
            defaults.set(searches, forKey: Self.key)
        }
    }
}

enum RecentSearches {
    static let limit = 6

    static func adding(_ query: String, to searches: [String]) -> [String] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 2 else { return searches }
        let key = SearchText.fold(text)
        let rest = searches.filter { SearchText.fold($0) != key }
        return Array(([text] + rest).prefix(limit))
    }
}
