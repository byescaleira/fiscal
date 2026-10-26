import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

public struct HighlightRef: Codable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let kind: Highlight.Kind
    public let weight: Int
    public let date: CalendarDay
    public let person: PersonCard?
    public let uncertainty: String?

    public init(_ highlight: Highlight) {
        id = highlight.id
        title = highlight.title
        kind = highlight.kind
        weight = highlight.weight
        date = highlight.date
        person = highlight.person
        uncertainty = highlight.coverage.uncertainty
    }
}

public enum InvestigationPiece: Codable, Hashable, Identifiable, Sendable {
    case person(PersonCard)
    case vote(VoteSummary)
    case theme(Theme)
    case place(Place)
    case party(String)
    case spending(PersonCard)
    case checks(PersonCard)
    case context(PersonCard)
    case highlight(HighlightRef)

    public enum Kind: String, CaseIterable, Identifiable, Sendable {
        case person, vote, place, theme, party, spending, checks, context, highlight

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .person: String(appLocalized: "Person")
            case .vote: String(appLocalized: "Vote")
            case .place: String(appLocalized: "Place")
            case .theme: String(appLocalized: "Topic")
            case .party: String(appLocalized: "Party")
            case .spending: String(appLocalized: "Spending")
            case .checks: String(appLocalized: "Fact checks")
            case .context: String(appLocalized: "Before and during the term")
            case .highlight: String(appLocalized: "Highlight")
            }
        }

        public var symbol: String {
            switch self {
            case .person: "person.crop.circle"
            case .vote: "checklist"
            case .place: "mappin.and.ellipse"
            case .theme: "square.grid.2x2"
            case .party: "flag"
            case .spending: "brazilianrealsign.circle"
            case .checks: "checkmark.shield"
            case .context: "chart.line.uptrend.xyaxis"
            case .highlight: "sparkle"
            }
        }

        public var color: Color {
            switch self {
            case .person: .retroDenim
            case .vote: .retroTeal
            case .place: .retroOlive
            case .theme: .retroPlum
            case .party: .retroBrown
            case .spending: .retroMustard
            case .checks: .retroRust
            case .context: .retroOrange
            case .highlight: .retroTeal
            }
        }

        public var needsPerson: Bool {
            self == .spending || self == .checks || self == .context
        }
    }

    public var kind: Kind {
        switch self {
        case .person: .person
        case .vote: .vote
        case .theme: .theme
        case .place: .place
        case .party: .party
        case .spending: .spending
        case .checks: .checks
        case .context: .context
        case .highlight: .highlight
        }
    }

    public var id: String {
        switch self {
        case .person(let card): "person-\(card.slug)"
        case .vote(let vote): "vote-\(vote.id)"
        case .theme(let theme): "theme-\(theme.rawValue)"
        case .place(let place): "place-\(place.code)"
        case .party(let party): "party-\(SearchText.fold(party))"
        case .spending(let card): "spending-\(card.slug)"
        case .checks(let card): "checks-\(card.slug)"
        case .context(let card): "context-\(card.slug)"
        case .highlight(let ref): "highlight-\(ref.id)"
        }
    }

    public var person: PersonCard? {
        switch self {
        case .person(let card), .spending(let card), .checks(let card), .context(let card):
            card
        case .highlight(let ref): ref.person
        case .vote, .theme, .place, .party: nil
        }
    }

    public var title: String {
        switch self {
        case .person(let card): card.name
        case .vote(let vote): vote.proposition
        case .theme(let theme): theme.title
        case .place(let place): SearchToken.place(place).title
        case .party(let party): party
        case .spending(let card): String(appLocalized: "Spending of \(card.name)")
        case .checks(let card): String(appLocalized: "Fact checks on \(card.name)")
        case .context(let card): String(appLocalized: "Before and during \(card.name)")
        case .highlight(let ref): ref.title
        }
    }

    public var detail: String {
        switch self {
        case .person(let card):
            card.uf == "br" ? card.officeTitle : "\(card.officeTitle) · \(card.uf.uppercased())"
        case .vote(let vote): vote.plainSummary ?? vote.summary
        case .theme(let theme): theme.coverage
        case .place(let place):
            place.isState
                ? String(appLocalized: "State")
                : String(appLocalized: "City in \(place.uf.uppercased())")
        case .party: String(appLocalized: "Party")
        case .spending: String(appLocalized: "Office allowance against peers")
        case .checks: String(appLocalized: "Projeto Comprova")
        case .context: String(appLocalized: "Prices since taking office")
        case .highlight(let ref): Relevance(weight: ref.weight).title
        }
    }

    public var symbol: String {
        switch self {
        case .theme(let theme): theme.symbol
        case .place(let place): place.isState ? "map" : "mappin.and.ellipse"
        default: kind.symbol
        }
    }
}

extension Array where Element == InvestigationPiece {
    var people: [PersonCard] {
        var seen = Set<String>()
        return compactMap(\.person).filter { seen.insert($0.slug).inserted }
    }

    var votes: [VoteSummary] {
        compactMap { piece in
            if case .vote(let vote) = piece { return vote }
            return nil
        }
    }

    var themes: [Theme] {
        compactMap { piece in
            if case .theme(let theme) = piece { return theme }
            return nil
        }
    }

    var places: [Place] {
        compactMap { piece in
            if case .place(let place) = piece { return place }
            return nil
        }
    }

    var parties: [String] {
        compactMap { piece in
            if case .party(let party) = piece { return party }
            return nil
        }
    }

    func has(_ kind: InvestigationPiece.Kind, for slug: String) -> Bool {
        contains { $0.kind == kind && $0.person?.slug == slug }
    }
}
