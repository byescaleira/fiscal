import Foundation

public struct FollowingSeenStore: Sendable {
    public static let key = "fiscal.following.seen"
    private let suiteName: String?

    public init(suiteName: String? = nil) {
        self.suiteName = suiteName
    }

    private var defaults: UserDefaults {
        suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    private var marks: [String: Date] {
        defaults.dictionary(forKey: Self.key) as? [String: Date] ?? [:]
    }

    public func seen(_ slug: String) -> Date? {
        marks[slug]
    }

    public func markSeen(_ slugs: [String], at date: Date) {
        var marks = marks
        for slug in slugs { marks[slug] = date }
        defaults.set(marks, forKey: Self.key)
    }

    public func forget(keeping slugs: Set<String>) {
        defaults.set(marks.filter { slugs.contains($0.key) }, forKey: Self.key)
    }
}
