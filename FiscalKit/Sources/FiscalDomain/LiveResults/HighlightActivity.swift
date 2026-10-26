import Foundation

public struct HighlightActivityState: Codable, Hashable, Sendable {
    public let weight: Int
    public let endsAt: Double

    public init(weight: Int, endsAt: Double) {
        self.weight = weight
        self.endsAt = endsAt
    }

    public init(highlight: Highlight, now: Date = .now) {
        self.init(
            weight: highlight.weight,
            endsAt: now.addingTimeInterval(HighlightAlertRule.lifetime).timeIntervalSince1970)
    }

    public var endDate: Date { Date(timeIntervalSince1970: endsAt) }
}

public protocol HighlightAlertService: Sendable {
    func registerHighlights(pushToken: String, environment: PushEnvironment) async throws
    func unregisterHighlights(pushToken: String) async throws
}

#if canImport(ActivityKit) && os(iOS)
    import ActivityKit

    public struct HighlightActivityAttributes: ActivityAttributes {
        public typealias ContentState = HighlightActivityState

        public let highlightId: String
        public let kind: String
        public let title: String
        public let subtitle: String
        public let date: String
        public let route: String
        public let personName: String?
        public let personSlug: String?
        public let party: String?

        public init(
            highlightId: String, kind: String, title: String, subtitle: String, date: String,
            route: String, personName: String?, personSlug: String?, party: String?
        ) {
            self.highlightId = highlightId
            self.kind = kind
            self.title = title
            self.subtitle = subtitle
            self.date = date
            self.route = route
            self.personName = personName
            self.personSlug = personSlug
            self.party = party
        }

        public init(highlight: Highlight) {
            self.init(
                highlightId: highlight.id, kind: highlight.kind.rawValue, title: highlight.title,
                subtitle: highlight.subtitle, date: highlight.date.description,
                route: highlight.route, personName: highlight.person?.name,
                personSlug: highlight.person?.slug, party: highlight.person?.party)
        }

        public func board(weight: Int) -> HighlightBoard {
            HighlightBoard(
                id: highlightId, kind: Highlight.Kind(rawValue: kind) ?? .action, title: title,
                subtitle: subtitle, weight: weight, day: CalendarDay(date) ?? CalendarDay(.now),
                route: route, personName: personName, personSlug: personSlug, party: party)
        }
    }
#endif
