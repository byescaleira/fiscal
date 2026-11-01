import FeatureCore
import FiscalDomain
import Foundation

extension MineModel {
    public func route(for update: FollowingUpdate) -> Route? {
        switch update.kind {
        case .vote(let vote): .vote(id: vote.voteId)
        case .expenses(let year, _, _): .expenses(slug: update.person.slug, year: year)
        case .check: nil
        }
    }

    public func title(for update: FollowingUpdate) -> String {
        switch update.kind {
        case .vote(let vote): vote.summary
        case .expenses:
            String(appLocalized: "Spending in \(Self.monthName(update.day))")
        case .check(let check): check.title
        }
    }

    public func detail(for update: FollowingUpdate) -> String {
        let date = update.day.date().formatted(
            Date.FormatStyle(locale: .app).day().month(.abbreviated))
        switch update.kind {
        case .vote(let vote):
            return String(appLocalized: "Voted \(vote.vote) · \(vote.proposition) · \(date)")
        case .expenses(_, _, let cents):
            return String(appLocalized: "\(PublicFormat.money(cents: cents)) in receipts · Chamber")
        case .check(let check):
            let verdict = check.verdict.map { "\($0) · " } ?? ""
            return String(appLocalized: "\(verdict)\(check.publisher) · \(date)")
        }
    }

    public var missingText: String {
        let names = missing.map(\.name).formatted(.list(type: .and).locale(.app))
        return String(appLocalized: "Couldn't load \(names). Tap to try again.")
    }

    static func monthName(_ day: CalendarDay) -> String {
        day.date().formatted(Date.FormatStyle(locale: .app).month(.wide))
    }
}
