import Foundation
import Testing

@testable import FiscalDomain

struct LikedItemTests {
    private let likedAt = Date(timeIntervalSince1970: 1_793_000_000)

    private func day() throws -> CalendarDay {
        try #require(CalendarDay(year: 2026, month: 10, day: 14))
    }

    @Test func aVoteKeepsItsIDAndTheVoteDestination() throws {
        let item = FeedItem(
            id: "vote-camara-2236186-60", kind: .vote, date: try day(),
            title: "PLP 281/2019", reason: .relevant, voteID: "camara-2236186-60")
        let liked = LikedItem(item: item, likedAt: likedAt)
        #expect(liked.id == "vote-camara-2236186-60")
        #expect(liked.kind == .vote)
        #expect(liked.title == "PLP 281/2019")
        #expect(liked.day == (try day()))
        #expect(liked.voteID == "camara-2236186-60")
        #expect(liked.expensesSlug == nil)
        #expect(liked.likedAt == likedAt)
    }

    @Test func expensesKeepTheMonthDestination() throws {
        let item = FeedItem(
            id: "expenses-pessoa-a-2026-10", kind: .expenses, date: try day(),
            title: "Gastos de outubro", reason: .relevant,
            expenses: FeedExpenses(slug: "pessoa-a", year: 2026, month: 10, cents: 120_000))
        let liked = LikedItem(item: item, likedAt: likedAt)
        #expect(liked.kind == .expenses)
        #expect(liked.expensesSlug == "pessoa-a")
        #expect(liked.expensesYear == 2026)
        #expect(liked.voteID == nil)
    }

    @Test func aFactCheckKeepsItsLink() throws {
        let url = try #require(URL(string: "https://projetocomprova.com.br/publicações/1"))
        let item = FeedItem(
            id: "check-1", kind: .check, date: try day(), title: "Checagem", reason: .relevant,
            url: url)
        let liked = LikedItem(item: item, likedAt: likedAt)
        #expect(liked.kind == .check)
        #expect(liked.url == url)
    }

    @Test func aVoteHighlightPointsToTheHighlightAndTheVote() throws {
        let highlight = Highlight(
            id: "h-1", kind: .vote, title: "PEC 221/2019", subtitle: "Senado", weight: 60,
            repercussion: nil, impact: 60, route: "senado-7107", person: nil,
            proposition: "PEC 221/2019", date: try day(), url: nil, signals: .none)
        let liked = LikedItem(highlight: highlight, likedAt: likedAt)
        #expect(liked.id == "highlight-h-1")
        #expect(liked.kind == .highlight)
        #expect(liked.highlightID == "h-1")
        #expect(liked.voteID == "senado-7107")
    }

    @Test func anArchiveRoundTripsTheItem() throws {
        let liked = LikedItem(
            id: "event-1", kind: .event, title: "Sessão", day: try day(), likedAt: likedAt,
            url: URL(string: "https://www.camara.leg.br/1"))
        let data = try JSONEncoder().encode(liked)
        #expect(try JSONDecoder().decode(LikedItem.self, from: data) == liked)
    }
}
