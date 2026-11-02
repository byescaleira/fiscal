import FiscalDomain
import Foundation

public enum Route: Hashable, Sendable {
    case person(slug: String)
    case vote(id: String)
    case voteBallots(id: String, party: String?)
    case expenses(slug: String, year: Int)
    case compare(slugs: [String])
    case races
    case race(id: String)
    case roster(title: String, people: [PersonCard])
    case spenders(title: String, spenders: [MoneyPlaces.Spender], year: Int?)
    case awaiting
    case memory
    case pastElection(year: Int)
    case pastRace(id: String)
    case period(id: String)
    case studyGuide(id: String)
    case artists
    case settings
    case share(ShareSubject)
    case content(ContentDetail)
    case highlight(id: String)
    case support
}

extension Route {
    public static func destination(for item: FeedItem) -> Route? {
        if let id = item.voteID { return .vote(id: id) }
        if let expenses = item.expenses {
            return .expenses(slug: expenses.slug, year: expenses.year)
        }
        return item.content.map { .content($0) }
    }

    public static func destination(for event: SupportEvent) -> Route? {
        if let id = event.voteID { return .vote(id: id) }
        return event.content.map { .content($0) }
    }

    public static func destination(
        for highlight: Highlight, method: WeightMethod?, sourceLine: String? = nil,
        isShareable: Bool = false
    ) -> Route {
        guard highlight.kind != .vote else { return .vote(id: highlight.route) }
        return .content(
            ContentDetail(
                highlight: highlight, method: method, sourceLine: sourceLine,
                shareHighlightID: isShareable ? highlight.id : nil))
    }
}
