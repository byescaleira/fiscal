import FiscalDomain
import Foundation
import SwiftData

@Model
public class LikeEntity {
    #Index<LikeEntity>([\.itemID], [\.likedAt])
    public var itemID: String = ""
    public var kind: String = ""
    public var title: String = ""
    public var day: String = ""
    public var likedAt: Date = Date.distantPast
    public var voteID: String?
    public var expensesSlug: String?
    public var expensesYear: Int?
    public var highlightID: String?
    public var url: String?

    public init(item: LikedItem) {
        itemID = item.id
        update(with: item)
    }

    func update(with item: LikedItem) {
        kind = item.kind.rawValue
        title = item.title
        day = item.day.description
        likedAt = item.likedAt
        voteID = item.voteID
        expensesSlug = item.expensesSlug
        expensesYear = item.expensesYear
        highlightID = item.highlightID
        url = item.url?.absoluteString
    }

    var liked: LikedItem? {
        guard let kind = LikedItem.Kind(rawValue: kind), let day = CalendarDay(day) else {
            return nil
        }
        return LikedItem(
            id: itemID, kind: kind, title: title, day: day, likedAt: likedAt, voteID: voteID,
            expensesSlug: expensesSlug, expensesYear: expensesYear, highlightID: highlightID,
            url: url.flatMap(URL.init(string:)))
    }
}
