import FeatureCore
import FiscalDomain
import Foundation

extension ProfileModel {
    public static let actionsLimit = 8

    public var actionItems: [ActionItem] {
        Array((actions?.items ?? []).prefix(Self.actionsLimit))
    }

    public var actionsTotalText: String? {
        guard let count = actions?.items.count, count > Self.actionsLimit else { return nil }
        return String(
            appLocalized: "Showing the \(Self.actionsLimit) of greatest weight out of \(count).")
    }

    public var actionsRuleText: String {
        String(
            appLocalized:
                "Ordered by weight, from 0 to 100: repercussion plus impact, with the same rule for every politician. A source that wasn't measured is left out of the count, never counted as zero."
        )
    }

    public var actionsSourceText: String? {
        actions.flatMap { SourceFootnote.text($0.sources, calendar: calendar) }
    }

    public func actionKicker(_ item: ActionItem) -> String {
        let kind =
            switch item.kind {
            case .proposal: String(appLocalized: "Proposal")
            case .vote: String(appLocalized: "Vote")
            case .speech: String(appLocalized: "Speech")
            }
        return [kind, item.proposition, shortDay(item.date)].compactMap(\.self)
            .joined(separator: " · ")
    }

    public func actionBallot(_ item: ActionItem) -> ProfileBallot? {
        item.ballot.map(ProfileBallot.init)
    }

    public func actionRoute(_ item: ActionItem) -> Route? {
        guard item.kind == .vote, let ref = item.ref else { return nil }
        return .vote(id: ref)
    }

    public func actionAccessibility(_ item: ActionItem) -> String {
        let weight = item.coverage.spoken(
            weight: item.weight, repercussion: item.repercussion, impact: item.impact)
        return "\(actionKicker(item)). \(item.title). \(weight)"
    }
}
