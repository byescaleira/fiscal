import FeatureCore
import FiscalDomain
import Foundation

extension FeedModel {
    public func kicker(_ item: FeedItem) -> String {
        let kind =
            switch item.kind {
            case .vote: String(appLocalized: "Vote")
            case .proposal: String(appLocalized: "Proposal")
            case .speech: String(appLocalized: "Speech")
            case .expenses: String(appLocalized: "Spending")
            case .check: String(appLocalized: "Fact Check")
            case .event: String(appLocalized: "Today in Congress")
            case .highlight: String(appLocalized: "Highlight")
            }
        guard let reference = item.reference, reference != kind else { return kind }
        return "\(kind) · \(reference)"
    }

    public func reasonText(_ item: FeedItem) -> String {
        switch item.reason {
        case .following: String(appLocalized: "You follow")
        case .region(let name): name
        case .relevant: String(appLocalized: "Relevant")
        }
    }

    public func symbol(_ item: FeedItem) -> String {
        FeedLikedText.symbol(LikedItem.Kind(item.kind))
    }

    public func dayText(_ item: FeedItem) -> String {
        let style = Date.FormatStyle(locale: .app)
        let date = item.date.date()
        if item.expenses != nil {
            return date.formatted(style.month(.abbreviated).year())
        }
        guard item.date.year == currentYear else {
            return date.formatted(style.day().month(.abbreviated).year())
        }
        return date.formatted(style.day().month(.abbreviated))
    }

    public func amount(_ expenses: FeedExpenses) -> String {
        PublicFormat.money(cents: expenses.cents)
    }

    public func expensesTitle(_ item: FeedItem) -> String {
        let month = item.date.date().formatted(Date.FormatStyle(locale: .app).month(.wide))
        return String(appLocalized: "Spending in \(month)")
    }

    public func ballotText(_ ballot: SupportBallot) -> String {
        BallotChoice(vote: ballot.vote)?.title ?? ballot.vote
    }

    public func soleBallotText(_ ballot: SupportBallot) -> String {
        String(appLocalized: "Vote: \(ballotText(ballot))")
    }

    private func sourceText(_ item: FeedItem) -> String? {
        guard Route.destination(for: item) == nil, item.url != nil else { return nil }
        return String(appLocalized: "See the Source")
    }

    public func accessibility(_ item: FeedItem) -> String {
        let title = item.expenses == nil ? item.title : expensesTitle(item)
        let parts =
            [reasonText(item), dayText(item), kicker(item), title]
            + item.people.map(\.name)
            + item.ballots.map { "\($0.person.name): \(ballotText($0))" }
            + [item.expenses.map(amount), item.detail, sourceText(item)].compactMap(\.self)
        return parts.joined(separator: ". ")
    }
}
