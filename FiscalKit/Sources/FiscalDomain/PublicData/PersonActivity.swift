import Foundation

public struct PersonVote: Codable, Hashable, Identifiable, Sendable {
    public let voteId: String
    public let date: CalendarDay
    public let proposition: String
    public let summary: String
    public let vote: String
    public let partyGuidance: String?
    public let approved: Bool?
    public let themes: [Theme]

    public init(
        voteId: String, date: CalendarDay, proposition: String, summary: String, vote: String,
        partyGuidance: String?, approved: Bool?, themes: [Theme]
    ) {
        self.voteId = voteId
        self.date = date
        self.proposition = proposition
        self.summary = summary
        self.vote = vote
        self.partyGuidance = partyGuidance
        self.approved = approved
        self.themes = themes
    }

    public var id: String { voteId }
}

public struct Proposal: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let kind: String
    public let number: Int
    public let year: Int
    public let summary: String
    public let plainSummary: String?
    public let canBecomeLaw: Bool?
    public let themes: [Theme]
    public let url: URL?

    public init(
        id: String, kind: String, number: Int, year: Int, summary: String,
        plainSummary: String?, canBecomeLaw: Bool?, themes: [Theme], url: URL?
    ) {
        self.id = id
        self.kind = kind
        self.number = number
        self.year = year
        self.summary = summary
        self.plainSummary = plainSummary
        self.canBecomeLaw = canBecomeLaw
        self.themes = themes
        self.url = url
    }

    public var reference: String { "\(kind) \(number)/\(year)" }
}

public struct Speech: Codable, Hashable, Sendable {
    public let date: CalendarDay
    public let kind: String
    public let summary: String
    public let url: URL?

    public init(date: CalendarDay, kind: String, summary: String, url: URL?) {
        self.date = date
        self.kind = kind
        self.summary = summary
        self.url = url
    }
}

public struct Expense: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let year: Int
    public let month: Int
    public let category: String
    public let supplier: String
    public let document: String?
    public let cents: Int
    public let url: URL?

    public init(
        id: String, year: Int, month: Int, category: String, supplier: String,
        document: String?, cents: Int, url: URL?
    ) {
        self.id = id
        self.year = year
        self.month = month
        self.category = category
        self.supplier = supplier
        self.document = document
        self.cents = cents
        self.url = url
    }
}

public struct PublicList<Item: Codable & Hashable & Sendable>: Codable, Hashable, Sendable {
    public let items: [Item]
    public let total: Int

    public init(items: [Item], total: Int) {
        self.items = items
        self.total = total
    }

    public static var empty: PublicList { PublicList(items: [], total: 0) }
}

public struct ExpenseList: Codable, Hashable, Sendable {
    public struct MonthTotal: Codable, Hashable, Sendable {
        public let month: Int
        public let cents: Int

        public init(month: Int, cents: Int) {
            self.month = month
            self.cents = cents
        }
    }

    public struct CategoryTotal: Codable, Hashable, Sendable {
        public let category: String
        public let cents: Int
        public let count: Int

        public init(category: String, cents: Int, count: Int) {
            self.category = category
            self.cents = cents
            self.count = count
        }
    }

    public let items: [Expense]
    public let totalCents: Int
    public let byMonth: [MonthTotal]
    public let byCategory: [CategoryTotal]

    public init(
        items: [Expense], totalCents: Int, byMonth: [MonthTotal], byCategory: [CategoryTotal]
    ) {
        self.items = items
        self.totalCents = totalCents
        self.byMonth = byMonth
        self.byCategory = byCategory
    }

    public static var empty: ExpenseList {
        ExpenseList(items: [], totalCents: 0, byMonth: [], byCategory: [])
    }
}
