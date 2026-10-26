import FeatureCore
import FiscalDomain
import Foundation

extension TodayModel {
    public static let highlightSecondaryLimit = 3

    public var highlightLead: Highlight? { highlights?.items.first }

    public var highlightOthers: [Highlight] {
        Array((highlights?.items ?? []).dropFirst().prefix(Self.highlightSecondaryLimit))
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
        String(
            appLocalized:
                "\(highlightKicker(highlight)). \(highlight.title). \(highlight.subtitle). Weight \(highlight.weight) of 100, repercussion \(highlight.repercussion), impact \(highlight.impact)."
        )
    }
}
