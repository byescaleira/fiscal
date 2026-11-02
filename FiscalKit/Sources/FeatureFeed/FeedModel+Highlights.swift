import FeatureCore
import FiscalDomain
import Foundation

extension FeedModel {
    public var highlightLead: Highlight? { highlights?.items.first }

    public var highlightMethod: WeightMethod? { highlights?.method }

    public var highlightSource: String? {
        guard let highlights else { return nil }
        return SourceFootnote.text(highlights.sources)
    }

    public func route(for highlight: Highlight) -> Route {
        .destination(
            for: highlight, method: highlightMethod, sourceLine: highlightSource, isShareable: true)
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
        let date = highlight.date.date().formatted(
            Date.FormatStyle(locale: .app).day(.twoDigits).month(.twoDigits))
        return "\(kind) · \(date)"
    }

    public func highlightAccessibility(_ highlight: Highlight) -> String {
        let weight = highlight.coverage.spoken(
            weight: highlight.weight, repercussion: highlight.repercussion,
            impact: highlight.impact)
        let tally = highlight.tally.map {
            String(appLocalized: "\($0.yes) yes, \($0.no) no.")
        }
        return [
            "\(highlightKicker(highlight)). \(highlight.plainSummary ?? highlight.title). \(highlight.subtitle).",
            tally,
            weight,
        ]
        .compactMap(\.self).joined(separator: " ")
    }

    public func highlightHeroOverline(_ highlight: Highlight) -> String {
        [highlightKicker(highlight), highlightStage(highlight)].compactMap(\.self)
            .filter { !$0.isEmpty }.joined(separator: " · ").uppercased(with: .app)
    }

    public func highlightReference(_ highlight: Highlight) -> String? {
        let house: String? =
            switch highlight.house {
            case .senado: String(appLocalized: "Senate")
            case .camara: String(appLocalized: "Chamber")
            case nil: nil
            }
        let parts = [house, highlight.proposition].compactMap(\.self).filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    public func highlightAuthorAccessibility(_ person: PersonCard) -> String {
        String(
            appLocalized:
                "Author: \(person.name), \(person.party), \(person.officeTitle), \(person.uf)")
    }

    public func authorLine(_ person: PersonCard) -> String {
        "\(person.officeTitle) · \(person.uf.uppercased(with: .app))"
    }

    public func highlightStage(_ highlight: Highlight) -> String? {
        guard let key = highlight.stage else { return nil }
        return highlightMethod?.stages.first { $0.key == key }?.label
    }

    public func highlightThemeSlot(_ highlight: Highlight) -> Int? {
        guard let theme = highlight.themes?.first,
            let index = Theme.allCases.firstIndex(of: theme)
        else { return nil }
        return index
    }
}
