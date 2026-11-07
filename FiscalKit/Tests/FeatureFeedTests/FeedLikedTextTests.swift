import FiscalDomain
import Foundation
import Testing

@testable import FeatureFeed

struct FeedLikedTextTests {
    @Test(arguments: [
        FeedItem.Kind.vote, .proposal, .speech, .expenses, .check, .event, .highlight,
    ])
    func aLikedItemShowsTheSameSymbolAsItsFeedRow(kind: FeedItem.Kind) throws {
        let day = try #require(CalendarDay(year: 2026, month: 10, day: 14))
        let item = FeedItem(id: "x", kind: kind, date: day, title: "T", reason: .relevant)
        let liked = LikedItem(item: item, likedAt: .now)
        #expect(liked.kind.rawValue == kind.rawValue)
        #expect(!FeedLikedText.symbol(liked.kind).isEmpty)
    }

    @Test func expensesShowTheMonthAndOthersTheDay() throws {
        let day = try #require(CalendarDay(year: 2026, month: 10, day: 14))
        let expenses = LikedItem(
            id: "e", kind: .expenses, title: "Gastos", day: day, likedAt: .now,
            expensesSlug: "a", expensesYear: 2026)
        let vote = LikedItem(id: "v", kind: .vote, title: "PLP", day: day, likedAt: .now)
        #expect(!FeedLikedText.day(expenses).contains("14"))
        #expect(FeedLikedText.day(vote).contains("14"))
        #expect(FeedLikedText.day(vote).contains("2026"))
    }
}
