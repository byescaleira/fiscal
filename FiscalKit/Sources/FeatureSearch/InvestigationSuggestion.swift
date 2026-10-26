import FeatureCore
import FiscalDomain
import Foundation

public struct InvestigationSuggestion: Hashable, Identifiable, Sendable {
    public enum Origin: Hashable, Sendable {
        case highlight, vote, followed, lens, topic, pair
    }

    public let origin: Origin
    public let question: String
    public let pieces: [InvestigationPiece]

    public var id: String { pieces.map(\.id).joined(separator: "+") }

    public var faces: [PersonCard] { pieces.people }

    public var kicker: String {
        switch origin {
        case .highlight: String(appLocalized: "Highlight of the Moment")
        case .vote: String(appLocalized: "Latest vote")
        case .followed: String(appLocalized: "Who you follow")
        case .lens: String(appLocalized: "Your Lens")
        case .topic: String(appLocalized: "Topic")
        case .pair: String(appLocalized: "Side by side")
        }
    }

    public var symbol: String {
        switch origin {
        case .highlight: "sparkle"
        case .vote: "checklist"
        case .followed: "person.crop.circle.badge.checkmark"
        case .lens: "camera.filters"
        case .topic: "square.grid.2x2"
        case .pair: "rectangle.split.2x1"
        }
    }
}

extension InvestigationModel {
    public static let suggestionLimit = 5

    func makeSuggestions() -> [InvestigationSuggestion] {
        var list: [InvestigationSuggestion] = []
        if let suggestion = highlightSuggestion { list.append(suggestion) }
        if let suggestion = voteSuggestion { list.append(suggestion) }
        if let suggestion = personSuggestion { list.append(suggestion) }
        if let suggestion = pairSuggestion { list.append(suggestion) }
        if let suggestion = topicSuggestion { list.append(suggestion) }
        var seen = Set<String>()
        return Array(list.filter { seen.insert($0.id).inserted }.prefix(Self.suggestionLimit))
    }

    private var highlightSuggestion: InvestigationSuggestion? {
        guard let item = highlights.first(where: { $0.person != nil }), let card = item.person
        else { return nil }
        let legislator = [Office.senator, .federalDeputy].contains(card.office)
        return InvestigationSuggestion(
            origin: .highlight,
            question: legislator
                ? String(appLocalized: "How does \(card.name)'s spending compare with peers?")
                : String(appLocalized: "Where does \(card.name) appear in the highlights?"),
            pieces: legislator
                ? [.person(card), .spending(card), .highlight(HighlightRef(item))]
                : [.person(card), .highlight(HighlightRef(item))])
    }

    private var voteSuggestion: InvestigationSuggestion? {
        guard let vote = recent.first(where: { $0.house == .camara && $0.nominal }) ?? recent.first
        else { return nil }
        let state = homeUF.flatMap { uf in
            index.places.first { $0.value.isState && $0.value.uf == uf }?.value
        }
        guard let state else {
            return InvestigationSuggestion(
                origin: .vote,
                question: String(
                    appLocalized: "Who voted against their own party on \(vote.proposition)?"),
                pieces: [.vote(vote)])
        }
        return InvestigationSuggestion(
            origin: .vote,
            question: String(
                appLocalized:
                    "Who from \(state.uf.uppercased()) voted against their own party on \(vote.proposition)?"
            ),
            pieces: [.vote(vote), .place(state)])
    }

    private var personSuggestion: InvestigationSuggestion? {
        let supported = lens?.supported.compactMap { slug in
            index.people.first { $0.value.slug == slug }?.value
        }
        if let card = supported?.first {
            return personQuestion(card, origin: .lens)
        }
        return followed.first.map { personQuestion($0, origin: .followed) }
    }

    private func personQuestion(_ card: PersonCard, origin: InvestigationSuggestion.Origin)
        -> InvestigationSuggestion
    {
        if card.office == .federalDeputy, let vote = recent.first(where: { $0.house == .camara }) {
            return InvestigationSuggestion(
                origin: origin,
                question: String(appLocalized: "How did \(card.name) vote on \(vote.proposition)?"),
                pieces: [.person(card), .vote(vote)])
        }
        return InvestigationSuggestion(
            origin: origin,
            question: String(appLocalized: "Were there fact checks about \(card.name)?"),
            pieces: [.person(card), .checks(card)])
    }

    private var pairSuggestion: InvestigationSuggestion? {
        guard let pair = CompareSuggestion.make(from: index.people.map(\.value)).first,
            pair.people.count >= 2
        else { return nil }
        let first = pair.people[0]
        let second = pair.people[1]
        return InvestigationSuggestion(
            origin: .pair,
            question: String(appLocalized: "How do \(first.name) and \(second.name) compare?"),
            pieces: [.person(first), .person(second)])
    }

    private var topicSuggestion: InvestigationSuggestion? {
        let themes = lens?.themes.isEmpty == false ? lens?.themes ?? [] : SearchModel.defaultThemes
        let touched = Set(recent.flatMap(\.themes))
        guard let theme = themes.first(where: touched.contains) else { return nil }
        return InvestigationSuggestion(
            origin: .topic,
            question: String(appLocalized: "What did Congress vote on \(theme.title)?"),
            pieces: [.theme(theme)])
    }
}
