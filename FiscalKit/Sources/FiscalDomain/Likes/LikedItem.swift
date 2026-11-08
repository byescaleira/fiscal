import Foundation

public struct LikedItem: Codable, Hashable, Identifiable, Sendable {
    public enum Kind: String, Codable, Hashable, Sendable {
        case vote, proposal, speech, expenses, check, event, highlight
    }

    public let id: String
    public let kind: Kind
    public let title: String
    public let day: CalendarDay
    public let likedAt: Date
    public let voteID: String?
    public let expensesSlug: String?
    public let expensesYear: Int?
    public let highlightID: String?
    public let url: URL?

    public init(
        id: String, kind: Kind, title: String, day: CalendarDay, likedAt: Date,
        voteID: String? = nil, expensesSlug: String? = nil, expensesYear: Int? = nil,
        highlightID: String? = nil, url: URL? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.day = day
        self.likedAt = likedAt
        self.voteID = voteID
        self.expensesSlug = expensesSlug
        self.expensesYear = expensesYear
        self.highlightID = highlightID
        self.url = url
    }

    public init(item: FeedItem, likedAt: Date) {
        self.init(
            id: item.id, kind: Kind(item.kind), title: item.title, day: item.date,
            likedAt: likedAt, voteID: item.voteID, expensesSlug: item.expenses?.slug,
            expensesYear: item.expenses?.year, url: item.url)
    }

    public init(highlight: Highlight, likedAt: Date) {
        self.init(
            id: Self.highlightID(highlight.id), kind: .highlight, title: highlight.title,
            day: highlight.date, likedAt: likedAt,
            voteID: highlight.kind == .vote ? highlight.route : nil,
            highlightID: highlight.id, url: highlight.url)
    }

    public static func highlightID(_ id: String) -> String { "highlight-\(id)" }
}

extension LikedItem.Kind {
    public init(_ kind: FeedItem.Kind) {
        switch kind {
        case .vote: self = .vote
        case .proposal: self = .proposal
        case .speech: self = .speech
        case .expenses: self = .expenses
        case .check: self = .check
        case .event: self = .event
        case .highlight: self = .highlight
        }
    }
}
