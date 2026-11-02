import FeatureCore
import FiscalDomain
import Foundation

public enum VoteChapter: String, CaseIterable, Identifiable, Sendable {
    case change, ballots, parties

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .change: String(appLocalized: "What Changes")
        case .ballots: String(appLocalized: "Who Voted")
        case .parties: String(appLocalized: "By Party")
        }
    }
}

extension VoteDetailModel {
    public var hasScore: Bool { vote?.yes != nil || vote?.no != nil }

    public var hasNames: Bool { vote?.nominal == true && !(detail?.people.isEmpty ?? true) }

    public var showsParties: Bool { vote?.nominal == true && !partyRows.isEmpty }

    public var hasPeopleToFollow: Bool {
        !supportedBallots.isEmpty || representatives != nil
    }

    public var chapters: [VoteChapter] {
        var chapters = [VoteChapter.change]
        if hasNames, hasPeopleToFollow { chapters.append(.ballots) }
        if showsParties { chapters.append(.parties) }
        if hasNames, !hasPeopleToFollow { chapters.append(.ballots) }
        return chapters
    }

    public var symbolicText: String? {
        guard let vote, !vote.nominal else { return nil }
        return String(
            appLocalized: "Voice vote: the house recorded the result, without each person's vote")
    }

    public var noNamesText: String? {
        guard let vote, vote.nominal, hasScore, !hasNames else { return nil }
        return String(appLocalized: "The house didn't publish who voted how.")
    }

    public var ballotsRoute: Route? {
        hasNames ? .voteBallots(id: id, party: nil) : nil
    }

    public var ballotsLinkTitle: String {
        String(appLocalized: "See the \(detail?.people.count ?? 0) votes")
    }

    public func ballotsRoute(party: String) -> Route? {
        hasNames ? .voteBallots(id: id, party: party) : nil
    }

    public var compactScore: String? {
        guard let vote, hasScore else { return nil }
        return "\(PublicFormat.number(vote.yes)) × \(PublicFormat.number(vote.no))"
    }
}
