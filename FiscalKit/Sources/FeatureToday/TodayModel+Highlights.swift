import FeatureCore
import FiscalDomain
import Foundation

extension TodayModel {
    public static let highlightSecondaryLimit = 3

    public var orderedHighlights: [Highlight] {
        let items = highlights?.items ?? []
        guard let lens, !lens.supported.isEmpty else { return items }
        return items.enumerated()
            .sorted { lhs, rhs in
                (lens.supportRank(of: lhs.element.person?.slug), lhs.offset)
                    < (lens.supportRank(of: rhs.element.person?.slug), rhs.offset)
            }
            .map(\.element)
    }

    public var highlightLead: Highlight? { orderedHighlights.first }

    public var highlightOthers: [Highlight] {
        Array(orderedHighlights.dropFirst().prefix(Self.highlightSecondaryLimit))
    }

    public func isSupportPick(_ highlight: Highlight) -> Bool {
        lens?.supports(highlight.person?.slug) == true
    }

    public var highlightMethod: WeightMethod? { highlights?.method }

    public var highlightSource: String? {
        guard let highlights else { return nil }
        return SourceFootnote.text(highlights.sources)
    }

    public func route(for highlight: Highlight) -> Route? {
        switch highlight.kind {
        case .action: .person(slug: highlight.route)
        case .vote: .vote(id: highlight.route)
        case .money, .indicator: nil
        }
    }

    public func shareSubject(for highlight: Highlight) -> ShareSubject {
        .highlight(id: highlight.id)
    }

    public func highlightKicker(_ highlight: Highlight) -> String {
        let kind =
            switch highlight.kind {
            case .action: String(appLocalized: "Proposal")
            case .vote: String(appLocalized: "Vote")
            case .money: String(appLocalized: "Money")
            case .indicator: String(appLocalized: "Indicator")
            }
        return "\(kind) · \(TodayText.shortDate(highlight.date.date()))"
    }

    public func highlightAccessibility(_ highlight: Highlight) -> String {
        let weight = highlight.coverage.spoken(
            weight: highlight.weight, repercussion: highlight.repercussion,
            impact: highlight.impact)
        let tally = highlight.tally.map {
            String(appLocalized: "\($0.yes) yes, \($0.no) no.")
        }
        return [
            "\(highlightKicker(highlight)). \(highlight.title). \(highlight.subtitle).", tally,
            weight,
        ]
        .compactMap(\.self).joined(separator: " ")
    }

    public func highlightStage(_ highlight: Highlight) -> String? {
        guard let key = highlight.stage else { return nil }
        return highlightMethod?.stages.first { $0.key == key }?.label
    }

    public func highlightPlace(_ highlight: Highlight) -> String? {
        let house: String? =
            switch highlight.house {
            case .senado: String(appLocalized: "Senate")
            case .camara: String(appLocalized: "Chamber")
            case nil: nil
            }
        let parts = [house, highlight.proposition, highlightStage(highlight)].compactMap(\.self)
            .filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    public func highlightThemeSlot(_ highlight: Highlight) -> Int? {
        guard let theme = highlight.themes?.first,
            let index = Theme.allCases.firstIndex(of: theme)
        else { return nil }
        return index
    }
}
