import Foundation
import Testing

@testable import FiscalDomain

struct FollowingFeedTests {
    private static let today = CalendarDay(year: 2026, month: 10, day: 31)!

    static func card(_ slug: String, _ name: String) -> PersonCard {
        PersonCard(
            slug: slug, name: name, office: .federalDeputy, uf: "sp", party: "PSD", photo: nil,
            status: .inOffice)
    }

    static func vote(_ id: String, day: Int, month: Int = 10) -> PersonVote {
        PersonVote(
            voteId: id, date: CalendarDay(year: 2026, month: month, day: day)!,
            proposition: "PL 1/2026", summary: "Resumo", vote: "Sim", partyGuidance: nil,
            approved: true, themes: [])
    }

    private static func check(_ id: String, day: Int) throws -> FactCheck {
        FactCheck(
            id: id, title: "Título", verdict: "Falso",
            date: CalendarDay(year: 2026, month: 10, day: day)!,
            url: try #require(URL(string: "https://projetocomprova.com.br/\(id)")),
            publisher: "Comprova", license: "CC BY-ND 4.0",
            licenseUrl: try #require(URL(string: "https://creativecommons.org/licenses/by-nd/4.0/"))
        )
    }

    @Test func ordersNewestFirstAcrossPeople() throws {
        let fulana = Self.card("fulana", "Fulana")
        let beltrano = Self.card("beltrano", "Beltrano")
        let expenses = ExpenseList(
            items: [], totalCents: 1_234_567,
            byMonth: [.init(month: 9, cents: 10), .init(month: 10, cents: 1_234_567)],
            byCategory: [])
        let updates = FollowingFeed.build(
            [
                .init(person: fulana, votes: [Self.vote("v1", day: 30)], expensesYear: 2026),
                .init(
                    person: beltrano, expenses: expenses, expensesYear: 2026,
                    checks: [try Self.check("c1", day: 29)]),
            ], today: Self.today)
        #expect(
            updates.map(\.id) == [
                "fulana/vote/v1", "beltrano/check/c1", "beltrano/expenses/2026-10",
            ])
        #expect(updates.last?.kind == .expenses(year: 2026, month: 10, cents: 1_234_567))
    }

    @Test func breaksTiesByNameThenId() {
        let updates = FollowingFeed.build(
            [
                .init(
                    person: Self.card("z", "Zélia"), votes: [Self.vote("a", day: 30)],
                    expensesYear: 2026),
                .init(
                    person: Self.card("a", "Ana"),
                    votes: [Self.vote("b", day: 30), Self.vote("a", day: 30)], expensesYear: 2026),
            ], today: Self.today)
        #expect(updates.map(\.id) == ["a/vote/a", "a/vote/b", "z/vote/a"])
    }

    @Test func keepsThirtyDaysAndFiftyItems() {
        let old = Self.vote("old", day: 30, month: 9)
        let edge = Self.vote("edge", day: 1)
        let many = (1...60).map { Self.vote("v\($0)", day: 15) }
        let updates = FollowingFeed.build(
            [.init(person: Self.card("a", "Ana"), votes: [old, edge] + many, expensesYear: 2026)],
            today: Self.today)
        #expect(updates.count == FollowingFeed.limit)
        #expect(!updates.contains { $0.id == "a/vote/old" })
        let few = FollowingFeed.build(
            [.init(person: Self.card("a", "Ana"), votes: [old, edge], expensesYear: 2026)],
            today: Self.today)
        #expect(few.map(\.id) == ["a/vote/edge"])
    }

    @Test func countsOnlyWhatIsNewSinceTheLastVisit() throws {
        let updates = FollowingFeed.build(
            [
                .init(
                    person: Self.card("a", "Ana"),
                    votes: [
                        Self.vote("old", day: 27), Self.vote("same", day: 28),
                        Self.vote("new", day: 30),
                    ],
                    expensesYear: 2026),
                .init(
                    person: Self.card("b", "Bia"), votes: [Self.vote("x", day: 30)],
                    expensesYear: 2026),
            ], today: Self.today)
        let seen = try #require(
            GregorianCalendar.current.date(
                from: DateComponents(year: 2026, month: 10, day: 28, hour: 18)))
        #expect(FollowingFeed.newCount(updates, seen: { $0 == "a" ? seen : nil }) == 1)
        #expect(FollowingFeed.newCount(updates, seen: { _ in seen }) == 2)
    }

    @Test func skipsMonthsWithoutSpending() {
        let expenses = ExpenseList(
            items: [], totalCents: 0, byMonth: [.init(month: 10, cents: 0)], byCategory: [])
        let updates = FollowingFeed.build(
            [.init(person: Self.card("a", "Ana"), expenses: expenses, expensesYear: 2026)],
            today: Self.today)
        #expect(updates.isEmpty)
    }
}
