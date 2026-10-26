import Foundation

public struct HighlightBoard: Hashable, Identifiable, Sendable {
    public let id: String
    public let kind: Highlight.Kind
    public let title: String
    public let subtitle: String
    public let weight: Int
    public let day: CalendarDay
    public let route: String
    public let personName: String?
    public let personSlug: String?
    public let party: String?

    public init(
        id: String, kind: Highlight.Kind, title: String, subtitle: String, weight: Int,
        day: CalendarDay, route: String, personName: String?, personSlug: String?,
        party: String?
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.weight = weight
        self.day = day
        self.route = route
        self.personName = personName
        self.personSlug = personSlug
        self.party = party
    }

    public init(_ highlight: Highlight) {
        self.init(
            id: highlight.id, kind: highlight.kind, title: highlight.title,
            subtitle: highlight.subtitle, weight: highlight.weight, day: highlight.date,
            route: highlight.route, personName: highlight.person?.name,
            personSlug: highlight.person?.slug, party: highlight.person?.party)
    }

    public var kindTitle: String {
        switch kind {
        case .action: String(appLocalized: "Proposal")
        case .vote: String(appLocalized: "Vote")
        case .money: String(appLocalized: "Money")
        case .indicator: String(appLocalized: "Indicator")
        }
    }

    public var kindSymbol: String {
        switch kind {
        case .action: "doc.text"
        case .vote: "checkmark.square"
        case .money: "brazilianrealsign"
        case .indicator: "chart.line.uptrend.xyaxis"
        }
    }

    public var dayText: String {
        day.date().formatted(.dateTime.day(.twoDigits).month(.twoDigits).locale(.app))
    }

    public var kicker: String {
        "\(kindTitle) · \(dayText)".uppercased(with: .app)
    }

    public var weightText: String {
        String(appLocalized: "Weight \(weight)")
    }

    public var weightShare: Double {
        min(max(Double(weight) / 100, 0), 1)
    }

    public var hasPerson: Bool {
        !(personName ?? "").isEmpty
    }

    public var url: URL? {
        IntegrationLink.highlight(kind: kind, route: route)
    }

    public var accessibilityText: String {
        String(
            appLocalized:
                "\(kindTitle), \(dayText). \(title). \(subtitle). Weight \(weight) of 100.")
    }
}

public struct HighlightDeck: Hashable, Sendable {
    public static let othersLimit = 3

    public let lead: HighlightBoard
    public let others: [HighlightBoard]

    public init(lead: HighlightBoard, others: [HighlightBoard]) {
        self.lead = lead
        self.others = others
    }

    public init?(list: HighlightList?) {
        guard let items = list?.items, let first = items.first else { return nil }
        lead = HighlightBoard(first)
        others = items.dropFirst().prefix(Self.othersLimit).map(HighlightBoard.init)
    }
}
