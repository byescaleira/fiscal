import Foundation

public struct SupportActivity: Hashable, Sendable {
    public let slug: String
    public let name: String
    public let counts: [Theme: Int]
    public let actionCount: Int

    public init(slug: String, name: String, counts: [Theme: Int], actionCount: Int = 0) {
        self.slug = slug
        self.name = name
        self.counts = counts.filter { $0.value > 0 }
        self.actionCount = actionCount
    }

    public init(slug: String, name: String, actions: ActionList?, profile: Profile?) {
        var counts: [Theme: Int] = [:]
        var actionCount = 0
        if let actions, !actions.items.isEmpty {
            actionCount = actions.items.count
            for item in actions.items {
                for theme in item.themes { counts[theme, default: 0] += 1 }
            }
        } else if let profile {
            for line in profile.themes {
                counts[line.key, default: 0] += line.proposals + line.speeches
            }
        }
        self.init(slug: slug, name: name, counts: counts, actionCount: actionCount)
    }

    public var usesActions: Bool { actionCount > 0 }

    public var total: Int { counts.values.reduce(0, +) }
}

public enum SupportThemes {
    public struct Entry: Hashable, Identifiable, Sendable {
        public let theme: Theme
        public let count: Int
        public let names: [String]

        public var id: Theme { theme }
    }

    public static func ranked(_ activity: [SupportActivity]) -> [Entry] {
        let neutral = Theme.neutralOrder
        return neutral.compactMap { theme -> Entry? in
            let people = activity.filter { ($0.counts[theme] ?? 0) > 0 }
            let count = people.reduce(0) { $0 + ($1.counts[theme] ?? 0) }
            guard count > 0 else { return nil }
            return Entry(theme: theme, count: count, names: people.map(\.name))
        }
        .sorted { lhs, rhs in
            lhs.count != rhs.count
                ? lhs.count > rhs.count
                : (neutral.firstIndex(of: lhs.theme) ?? 0)
                    < (neutral.firstIndex(of: rhs.theme) ?? 0)
        }
    }

    public static func order(_ activity: [SupportActivity]) -> [Theme] {
        let ranked = ranked(activity).map(\.theme)
        return ranked + Theme.neutralOrder.filter { !ranked.contains($0) }
    }

    public static func suggested(
        _ activity: [SupportActivity], prefersNotToSay: Bool = false,
        limit: Int = Lens.themeRange.upperBound
    ) -> [Theme] {
        let source = prefersNotToSay ? Theme.neutralOrder : order(activity)
        return Array(source.prefix(limit))
    }
}
