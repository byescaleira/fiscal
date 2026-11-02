import Foundation
import Testing

@testable import FiscalDomain

struct FeedTimelineTests {
    private let ana = Self.card("pessoa-a", "Pessoa A")
    private let bia = Self.card("pessoa-b", "Pessoa B")

    private static func card(_ slug: String, _ name: String) -> PersonCard {
        PersonCard(
            slug: slug, name: name, office: .federalDeputy, uf: "sp", party: "PSD", photo: nil,
            status: .inOffice)
    }

    private static func day(_ value: String) -> CalendarDay {
        CalendarDay(value) ?? CalendarDay(Date(timeIntervalSince1970: 1_792_917_720))
    }

    private static func vote(_ id: String, on date: String, ballot: String) -> PersonVote {
        PersonVote(
            voteId: id, date: day(date), proposition: "PL 1/2026", summary: "Votação \(id)",
            vote: ballot, partyGuidance: nil, approved: true, themes: [.health])
    }

    private static func recent(_ id: String, on date: String) -> VoteSummary {
        VoteSummary(
            id: id, house: .camara, date: day(date), time: nil, proposition: "PL 3/2026", kind: nil,
            summary: "Geral \(id)", plainSummary: nil, themes: [.taxes], result: nil, approved: nil,
            nominal: true, tally: VoteSummary.Tally(yes: 1, no: 1, others: 0))
    }

    private static func highlight(
        _ id: String, kind: Highlight.Kind = .action, on date: String = "2026-10-27",
        person: PersonCard? = nil, route: String = "pessoa-a"
    ) -> Highlight {
        Highlight(
            id: id, kind: kind, title: "Destaque \(id)", subtitle: "", weight: 60,
            repercussion: nil, impact: 60, route: route, person: person, proposition: nil,
            date: day(date), url: nil, signals: .none)
    }

    private static func activity(_ card: PersonCard, votes: [PersonVote]) -> FollowingFeed.Activity
    {
        FollowingFeed.Activity(person: card, votes: votes, expensesYear: 2_026)
    }

    @Test func newestComesFirstAndTiesAreStable() {
        let items = FeedTimeline.build(
            FeedSources(recent: [
                Self.recent("b", on: "2026-10-20"), Self.recent("a", on: "2026-10-20"),
                Self.recent("c", on: "2026-10-21"),
            ]))
        #expect(items.map(\.id) == ["vote-c", "vote-a", "vote-b"])
    }

    @Test func aVoteWhereTwoFollowedPeopleDifferIsOneLine() throws {
        let items = FeedTimeline.build(
            FeedSources(
                following: [ana, bia],
                activities: [
                    Self.activity(bia, votes: [Self.vote("1", on: "2026-10-20", ballot: "Não")]),
                    Self.activity(ana, votes: [Self.vote("1", on: "2026-10-20", ballot: "Sim")]),
                ],
                recent: [Self.recent("1", on: "2026-10-20")]))
        let item = try #require(items.first)
        #expect(items.count == 1)
        #expect(item.reason == .following)
        #expect(item.ballots.map(\.person.slug) == ["pessoa-a", "pessoa-b"])
        #expect(item.title == "Geral 1")
    }

    @Test func eachLineSaysWhyItIsThere() {
        let items = FeedTimeline.build(
            FeedSources(
                following: [ana],
                activities: [
                    Self.activity(ana, votes: [Self.vote("1", on: "2026-10-22", ballot: "Sim")])
                ],
                recent: [Self.recent("2", on: "2026-10-21")],
                highlights: HighlightList(
                    generatedAt: Date(timeIntervalSince1970: 1_792_917_720),
                    items: [
                        Self.highlight("action-lead"),
                        Self.highlight("action-sp", person: bia),
                    ], method: nil, sources: []),
                regionUF: "sp", regionName: "São Paulo"))
        let reasons = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0.reason) })
        #expect(reasons["vote-1"] == .following)
        #expect(reasons["vote-2"] == .relevant)
        #expect(reasons["action-sp"] == .region("São Paulo"))
    }

    @Test func theLeadHighlightStaysOutOfTheList() {
        let items = FeedTimeline.build(
            FeedSources(
                highlights: HighlightList(
                    generatedAt: Date(timeIntervalSince1970: 1_792_917_720),
                    items: [Self.highlight("action-lead"), Self.highlight("action-other")],
                    method: nil, sources: [])))
        #expect(items.map(\.id) == ["action-other"])
    }

    @Test func aLeadVoteOfSomeoneFollowedKeepsTheirBallotInTheList() {
        let list = HighlightList(
            generatedAt: Date(timeIntervalSince1970: 1_792_917_720),
            items: [Self.highlight("vote-1", kind: .vote, route: "1")], method: nil, sources: [])
        let followed = FeedTimeline.build(
            FeedSources(
                activities: [
                    Self.activity(ana, votes: [Self.vote("1", on: "2026-10-27", ballot: "Sim")])
                ], recent: [Self.recent("1", on: "2026-10-27")], highlights: list))
        #expect(followed.map(\.voteID) == ["1"])
        #expect(followed.first?.ballots.count == 1)
        let general = FeedTimeline.build(
            FeedSources(recent: [Self.recent("1", on: "2026-10-27")], highlights: list))
        #expect(general.isEmpty)
    }

    @Test func filtersKeepOnlyThatReason() {
        let items = FeedTimeline.build(
            FeedSources(
                following: [ana],
                activities: [
                    Self.activity(ana, votes: [Self.vote("1", on: "2026-10-22", ballot: "Sim")])
                ],
                recent: [Self.recent("2", on: "2026-10-21")]))
        #expect(FeedTimeline.filtered(items, by: .all).count == 2)
        #expect(FeedTimeline.filtered(items, by: .following).map(\.voteID) == ["1"])
        #expect(FeedTimeline.filtered(items, by: .relevant).map(\.voteID) == ["2"])
    }

    @Test func theRaceEventIsALineOnlyWithoutARaceOnTop() {
        let digest = TodayDigest(
            date: Self.day("2026-10-28"),
            events: [
                TodayDigest.Event(
                    kind: .race, title: "Apuração", summary: "", themes: [], ref: "br")
            ], sources: [])
        #expect(FeedTimeline.build(FeedSources(digest: digest, hidesRaces: true)).isEmpty)
        let items = FeedTimeline.build(FeedSources(digest: digest))
        #expect(items.map(\.title) == ["Apuração"])
        #expect(items.first?.content != nil)
    }

    @Test func theDailyEventsBecomeLinesAndTheRaceDoesNot() {
        let digest = TodayDigest(
            date: Self.day("2026-10-28"),
            events: [
                TodayDigest.Event(
                    kind: .session, title: "Sessão", summary: "Resumo", themes: [], ref: nil),
                TodayDigest.Event(
                    kind: .race, title: "Apuração", summary: "", themes: [], ref: "br"),
                TodayDigest.Event(
                    kind: .vote, title: "Votação", summary: "", themes: [], ref: "2"),
            ], sources: [])
        let items = FeedTimeline.build(
            FeedSources(
                recent: [Self.recent("2", on: "2026-10-28")], digest: digest, hidesRaces: true))
        #expect(items.count == 2)
        #expect(items.contains { $0.kind == .event && $0.content != nil })
        #expect(items.filter { $0.voteID == "2" }.count == 1)
        #expect(!items.contains { $0.title == "Apuração" })
    }

    @Test func expensesBecomeOneLinePerMonth() throws {
        let list = ExpenseList(
            items: [], totalCents: 300,
            byMonth: [
                ExpenseList.MonthTotal(month: 9, cents: 100),
                ExpenseList.MonthTotal(month: 10, cents: 200),
                ExpenseList.MonthTotal(month: 11, cents: 0),
            ],
            byCategory: [])
        let items = FeedTimeline.build(
            FeedSources(
                following: [ana],
                activities: [
                    FollowingFeed.Activity(person: ana, expenses: list, expensesYear: 2_026)
                ]))
        #expect(items.count == 2)
        #expect(items.first?.expenses?.month == 10)
        #expect(items.first?.expenses?.cents == 200)
    }
}
