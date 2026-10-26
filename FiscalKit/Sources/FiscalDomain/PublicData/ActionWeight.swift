import Foundation

public struct WeightSignals: Codable, Hashable, Sendable {
    public let news: Int?
    public let newsPerson: Int?
    public let wiki: Int?
    public let wikiTheme: Int?
    public let bluesky: Int?
    public let isTest: Bool

    enum CodingKeys: String, CodingKey {
        case news, newsPerson, wiki, wikiTheme, bluesky
        case isTest = "test"
    }

    public init(
        news: Int?, newsPerson: Int?, wiki: Int?, wikiTheme: Int?, bluesky: Int?,
        isTest: Bool = false
    ) {
        self.news = news
        self.newsPerson = newsPerson
        self.wiki = wiki
        self.wikiTheme = wikiTheme
        self.bluesky = bluesky
        self.isTest = isTest
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        news = try container.decodeIfPresent(Int.self, forKey: .news)
        newsPerson = try container.decodeIfPresent(Int.self, forKey: .newsPerson)
        wiki = try container.decodeIfPresent(Int.self, forKey: .wiki)
        wikiTheme = try container.decodeIfPresent(Int.self, forKey: .wikiTheme)
        bluesky = try container.decodeIfPresent(Int.self, forKey: .bluesky)
        isTest = try container.decodeIfPresent(Bool.self, forKey: .isTest) ?? false
    }

    public static let none = WeightSignals(
        news: nil, newsPerson: nil, wiki: nil, wikiTheme: nil, bluesky: nil)
}

public struct ActionItem: Codable, Hashable, Identifiable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case proposal, vote, speech
    }

    public let id: String
    public let kind: Kind
    public let title: String
    public let proposition: String?
    public let date: CalendarDay
    public let url: URL?
    public let ref: String?
    public let ballot: String?
    public let stage: String?
    public let themes: [Theme]
    public let weight: Int
    public let repercussion: Int
    public let impact: Int
    public let signals: WeightSignals

    public init(
        id: String, kind: Kind, title: String, proposition: String?, date: CalendarDay,
        url: URL?, ref: String?, ballot: String?, stage: String?, themes: [Theme], weight: Int,
        repercussion: Int, impact: Int, signals: WeightSignals
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.proposition = proposition
        self.date = date
        self.url = url
        self.ref = ref
        self.ballot = ballot
        self.stage = stage
        self.themes = themes
        self.weight = weight
        self.repercussion = repercussion
        self.impact = impact
        self.signals = signals
    }
}

public struct ActionList: Codable, Hashable, Sendable {
    public let items: [ActionItem]
    public let sources: [Source]

    public init(items: [ActionItem], sources: [Source]) {
        self.items = items
        self.sources = sources
    }
}

public struct Highlight: Codable, Hashable, Identifiable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case action, vote, money, indicator
    }

    public let id: String
    public let kind: Kind
    public let title: String
    public let subtitle: String
    public let weight: Int
    public let repercussion: Int
    public let impact: Int
    public let route: String
    public let person: PersonCard?
    public let proposition: String?
    public let date: CalendarDay
    public let url: URL?
    public let signals: WeightSignals

    public init(
        id: String, kind: Kind, title: String, subtitle: String, weight: Int,
        repercussion: Int, impact: Int, route: String, person: PersonCard?,
        proposition: String?, date: CalendarDay, url: URL?, signals: WeightSignals
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.weight = weight
        self.repercussion = repercussion
        self.impact = impact
        self.route = route
        self.person = person
        self.proposition = proposition
        self.date = date
        self.url = url
        self.signals = signals
    }
}

public struct HighlightList: Codable, Hashable, Sendable {
    public let generatedAt: Date?
    public let items: [Highlight]
    public let method: WeightMethod?
    public let sources: [Source]

    public init(generatedAt: Date?, items: [Highlight], method: WeightMethod?, sources: [Source]) {
        self.generatedAt = generatedAt
        self.items = items
        self.method = method
        self.sources = sources
    }
}

public struct WeightMethod: Codable, Hashable, Sendable {
    public struct Part: Codable, Hashable, Identifiable, Sendable {
        public let key: String
        public let label: String
        public let share: Double

        public init(key: String, label: String, share: Double) {
            self.key = key
            self.label = label
            self.share = share
        }

        public var id: String { key }
    }

    public struct Value: Codable, Hashable, Identifiable, Sendable {
        public let key: String
        public let label: String
        public let value: Double
        public let note: String?

        public init(key: String, label: String, value: Double, note: String? = nil) {
            self.key = key
            self.label = label
            self.value = value
            self.note = note
        }

        public var id: String { key }
    }

    public struct Signal: Codable, Hashable, Identifiable, Sendable {
        public let id: String
        public let name: String
        public let url: URL?
        public let measures: String
        public let window: String
        public let status: String
        public let note: String?

        public init(
            id: String, name: String, url: URL?, measures: String, window: String,
            status: String, note: String?
        ) {
            self.id = id
            self.name = name
            self.url = url
            self.measures = measures
            self.window = window
            self.status = status
            self.note = note
        }

        public var isMeasured: Bool { status == "measured" }
    }

    public struct Reach: Codable, Hashable, Identifiable, Sendable {
        public let key: String
        public let reach: Double
        public let reason: String

        public init(key: String, reach: Double, reason: String) {
            self.key = key
            self.reach = reach
            self.reason = reason
        }

        public var id: String { key }
    }

    public struct Decay: Codable, Hashable, Sendable {
        public let halfLifeDays: Int
        public let windowDays: Int
        public let text: String

        public init(halfLifeDays: Int, windowDays: Int, text: String) {
            self.halfLifeDays = halfLifeDays
            self.windowDays = windowDays
            self.text = text
        }
    }

    public let version: Int
    public let summary: String
    public let formula: String
    public let repercussion: String
    public let impact: String
    public let parts: [Part]
    public let signals: [Signal]
    public let impactParts: [Part]
    public let kinds: [Value]
    public let scopes: [Value]
    public let stages: [Value]
    public let themes: [Reach]
    public let decay: Decay
    public let rules: [String]
    public let limits: [String]
    public let sources: [Source]
    public let alert: HighlightAlertRule?

    public init(
        version: Int, summary: String, formula: String, repercussion: String, impact: String,
        parts: [Part], signals: [Signal], impactParts: [Part], kinds: [Value], scopes: [Value],
        stages: [Value], themes: [Reach], decay: Decay, rules: [String], limits: [String],
        sources: [Source], alert: HighlightAlertRule? = nil
    ) {
        self.version = version
        self.summary = summary
        self.formula = formula
        self.repercussion = repercussion
        self.impact = impact
        self.parts = parts
        self.signals = signals
        self.impactParts = impactParts
        self.kinds = kinds
        self.scopes = scopes
        self.stages = stages
        self.themes = themes
        self.decay = decay
        self.rules = rules
        self.limits = limits
        self.sources = sources
        self.alert = alert
    }

    public var alertRule: HighlightAlertRule { alert ?? .standard }
}
