import Foundation
import Testing

@testable import FiscalDomain

struct SupportTimelineTests {
    private let ana = Self.card("pessoa-a", "Pessoa A")
    private let bia = Self.card("pessoa-b", "Pessoa B")

    private static func card(_ slug: String, _ name: String, office: Office = .federalDeputy)
        -> PersonCard
    {
        PersonCard(
            slug: slug, name: name, office: office, uf: "sp", party: "PSD", photo: nil,
            status: .inOffice)
    }

    private static func day(_ value: String) -> CalendarDay {
        CalendarDay(value) ?? CalendarDay(Date(timeIntervalSince1970: 1_792_917_720))
    }

    private static func vote(
        _ id: String, on date: String, ballot: String, themes: [Theme] = [.health]
    ) -> PersonVote {
        PersonVote(
            voteId: id, date: day(date), proposition: "PL 1/2026", summary: "Votação \(id)",
            vote: ballot, partyGuidance: nil, approved: true, themes: themes)
    }

    private static func action(_ id: String, on date: String, kind: ActionItem.Kind = .proposal)
        -> ActionItem
    {
        ActionItem(
            id: id, kind: kind, title: "Proposta \(id)", proposition: "PL 2/2026", date: day(date),
            url: nil, ref: nil, ballot: nil, stage: nil, themes: [.education], weight: 50,
            repercussion: nil, impact: 50, signals: .none)
    }

    private static func recent(_ id: String, on date: String, themes: [Theme]) -> VoteSummary {
        VoteSummary(
            id: id, house: .camara, date: day(date), time: nil, proposition: "PL 3/2026", kind: nil,
            summary: "Geral \(id)", plainSummary: nil, themes: themes, result: nil, approved: nil,
            nominal: true, tally: VoteSummary.Tally(yes: 1, no: 1, others: 0))
    }

    private func sources(
        votes: [String: [PersonVote]] = [:], actions: [String: ActionList] = [:],
        recent: [VoteSummary] = []
    ) -> SupportSources {
        SupportSources(cards: [ana, bia], actions: actions, votes: votes, recent: recent)
    }

    @Test func aVoteWhereTwoPeopleDifferIsOneLineWithBothBallots() throws {
        let choice = SupportChoice(people: ["pessoa-a", "pessoa-b"])
        let events = SupportTimeline.build(
            choice,
            from: sources(votes: [
                "pessoa-b": [Self.vote("1", on: "2026-10-20", ballot: "Não")],
                "pessoa-a": [Self.vote("1", on: "2026-10-20", ballot: "Sim")],
            ]))
        let event = try #require(events.first)
        #expect(events.count == 1)
        #expect(event.kind == .vote)
        #expect(event.voteID == "1")
        #expect(event.ballots.map(\.person.slug) == ["pessoa-a", "pessoa-b"])
        #expect(event.ballots.map(\.vote) == ["Sim", "Não"])
    }

    @Test func newestComesFirstAndTiesAreStable() {
        let choice = SupportChoice(people: ["pessoa-a"])
        let list = ActionList(
            items: [
                Self.action("b", on: "2026-10-20"), Self.action("a", on: "2026-10-20"),
                Self.action("c", on: "2026-10-21"),
            ], sources: [])
        let events = SupportTimeline.build(choice, from: sources(actions: ["pessoa-a": list]))
        #expect(events.map(\.id) == ["action-c", "action-a", "action-b"])
    }

    @Test func aCauseBringsOnlyVotesWithThatTheme() {
        let choice = SupportChoice(causes: [.health])
        let events = SupportTimeline.build(
            choice,
            from: sources(recent: [
                Self.recent("1", on: "2026-10-20", themes: [.health, .taxes]),
                Self.recent("2", on: "2026-10-21", themes: [.taxes]),
            ]))
        #expect(events.map(\.voteID) == ["1"])
        #expect(events.first?.ballots.isEmpty == true)
    }

    @Test func aPersonNotChosenBringsNothing() {
        let choice = SupportChoice(people: ["pessoa-a"])
        let events = SupportTimeline.build(
            choice,
            from: sources(votes: ["pessoa-b": [Self.vote("1", on: "2026-10-20", ballot: "Sim")]]))
        #expect(events.isEmpty)
    }

    @Test func aCauseVoteAndAPersonVoteJoinAndKeepThePlainTitle() throws {
        let choice = SupportChoice(people: ["pessoa-a"], causes: [.health])
        let events = SupportTimeline.build(
            choice,
            from: sources(
                votes: ["pessoa-a": [Self.vote("1", on: "2026-10-20", ballot: "Sim")]],
                recent: [Self.recent("1", on: "2026-10-20", themes: [.health])]))
        let event = try #require(events.first)
        #expect(events.count == 1)
        #expect(event.title == "Geral 1")
        #expect(event.ballots.count == 1)
    }

    @Test func filtersKeepOnlyThePersonOrTheCause() {
        let choice = SupportChoice(people: ["pessoa-a", "pessoa-b"])
        let events = SupportTimeline.build(
            choice,
            from: sources(votes: [
                "pessoa-a": [Self.vote("1", on: "2026-10-20", ballot: "Sim")],
                "pessoa-b": [
                    Self.vote("2", on: "2026-10-21", ballot: "Não", themes: [.taxes])
                ],
            ]))
        #expect(events.count == 2)
        #expect(SupportTimeline.filtered(events, by: .all).count == 2)
        #expect(SupportTimeline.filtered(events, by: .person("pessoa-a")).map(\.voteID) == ["1"])
        #expect(SupportTimeline.filtered(events, by: .cause(.taxes)).map(\.voteID) == ["2"])
        #expect(SupportTimeline.filtered(events, by: .cause(.women)).isEmpty)
    }

    @Test func aProposalOpensItsContentWithoutShare() throws {
        let choice = SupportChoice(people: ["pessoa-a"])
        let list = ActionList(items: [Self.action("x", on: "2026-10-20")], sources: [])
        let event = try #require(
            SupportTimeline.build(choice, from: sources(actions: ["pessoa-a": list])).first)
        #expect(event.kind == .proposal)
        #expect(event.voteID == nil)
        #expect(event.content?.person == ana)
        #expect(event.content?.shareHighlightID == nil)
    }

    @Test func theListStopsAtTheLimit() {
        let choice = SupportChoice(people: ["pessoa-a"])
        let votes = (0..<(SupportTimeline.limit + 20)).map {
            Self.vote("\($0)", on: "2026-10-20", ballot: "Sim")
        }
        let events = SupportTimeline.build(choice, from: sources(votes: ["pessoa-a": votes]))
        #expect(events.count == SupportTimeline.limit)
    }

    @Test func onlyLegislativeOfficesPublishVotes() {
        #expect(Office.federalDeputy.publishesVotes)
        #expect(Office.senator.publishesVotes)
        #expect(Office.stateDeputy.publishesVotes)
        #expect(!Office.governor.publishesVotes)
    }
}
