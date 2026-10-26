import Foundation

public struct VoteBoard: Hashable, Identifiable, Sendable {
    public enum Outcome: Hashable, Sendable {
        case approved, rejected, unknown
    }

    public let id: String
    public let proposition: String
    public let summary: String
    public let house: House
    public let day: CalendarDay
    public let time: String?
    public let themes: [Theme]
    public let tally: VoteSummary.Tally
    public let outcome: Outcome
    private let result: String?

    public init(_ vote: VoteSummary) {
        id = vote.id
        proposition = vote.proposition
        summary = vote.plainSummary ?? vote.summary
        house = vote.house
        day = vote.date
        time = vote.time
        themes = vote.themes
        tally = vote.tally
        result = vote.result
        outcome =
            switch vote.approved {
            case true: .approved
            case false: .rejected
            case nil: .unknown
            }
    }

    public var yesText: String { PublicFormat.number(tally.yes) }

    public var noText: String { PublicFormat.number(tally.no) }

    public var othersText: String { PublicFormat.number(tally.others) }

    public var scoreText: String { "\(yesText) × \(noText)" }

    public var hasScore: Bool { tally.total.map { $0 > 0 } ?? false }

    public var yesShare: Double { share(tally.yes) }

    public var noShare: Double { share(tally.no) }

    public var othersShare: Double { share(tally.others) }

    private func share(_ value: Int?) -> Double {
        guard let total = tally.total, total > 0, let value else { return 0 }
        return Double(value) / Double(total)
    }

    public var outcomeTitle: String {
        switch outcome {
        case .approved: String(appLocalized: "Approved")
        case .rejected: String(appLocalized: "Rejected")
        case .unknown: result.flatMap { $0.isEmpty ? nil : $0 } ?? PublicFormat.missing
        }
    }

    public var outcomeSymbol: String {
        switch outcome {
        case .approved: "checkmark.seal"
        case .rejected: "xmark.seal"
        case .unknown: "circle.dashed"
        }
    }

    public var houseShort: String {
        switch house {
        case .camara: String(appLocalized: "Chamber")
        case .senado: String(appLocalized: "Senate")
        }
    }

    public var dayText: String {
        day.date().formatted(.dateTime.day(.twoDigits).month(.twoDigits).locale(.app))
    }

    public var whenText: String {
        guard let time, !time.isEmpty else { return dayText }
        return "\(dayText), \(time)"
    }

    public var eyebrow: String {
        "\(houseShort) · \(dayText)".uppercased(with: .app)
    }

    public var sourceText: String {
        IntegrationText.source(house.title, whenText)
    }

    public var accessibilityText: String {
        String(
            appLocalized:
                "\(proposition), \(house.title), \(whenText). Yes: \(yesText). No: \(noText). Other: \(othersText). \(outcomeTitle)."
        )
    }

    public var url: URL? { IntegrationLink.vote(id) }
}

public enum IntegrationText {
    public static func source(_ name: String, _ when: String) -> String {
        String(appLocalized: "Source: \(name) · \(when)")
    }

    public static func updated(_ name: String, _ date: Date?) -> String {
        guard let date else { return String(appLocalized: "Source: \(name)") }
        let when = date.formatted(
            .dateTime.day(.twoDigits).month(.twoDigits).hour().minute().locale(.app))
        return String(appLocalized: "Source: \(name) · updated \(when)")
    }
}

public enum IntegrationLink {
    public static let mine = URL(string: "fiscal://mine")
    public static let votes = URL(string: "fiscal://votes")
    public static let races = URL(string: "fiscal://races")
    public static let today = URL(string: "fiscal://today")

    public static func person(_ slug: String) -> URL? {
        path("person", slug)
    }

    public static func vote(_ id: String) -> URL? {
        path("vote", id)
    }

    public static func highlight(kind: Highlight.Kind, route: String) -> URL? {
        let link: URL? =
            switch kind {
            case .action: person(route)
            case .vote: vote(route)
            case .money, .indicator: nil
            }
        return link ?? today
    }

    private static func path(_ host: String, _ value: String) -> URL? {
        guard !value.isEmpty,
            let encoded = value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
        else { return nil }
        return URL(string: "fiscal://\(host)/\(encoded)")
    }
}
