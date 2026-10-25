import FiscalData
import FiscalDomain
import Foundation
import Testing

@testable import FeatureCore

struct RepresentativeBallotsTests {
    private func detail(_ people: [VoteDetail.Ballot]) -> VoteDetail {
        VoteDetail(
            vote: VoteSummary(
                id: "camara-1", house: .camara,
                date: CalendarDay("2026-10-21") ?? CalendarDay(.now),
                time: "18:42", proposition: "PL 1873/2026", kind: nil, summary: "Altera a lei.",
                plainSummary: nil, themes: [], result: "Aprovado", approved: true, nominal: true,
                tally: .init(yes: 412, no: 49, others: 9)),
            quorum: 257, guidance: [], parties: [], people: people, sources: [])
    }

    private func ballot(_ name: String, _ uf: String, _ vote: String) -> VoteDetail.Ballot {
        VoteDetail.Ballot(slug: name.lowercased(), name: name, party: "PSD", uf: uf, vote: vote)
    }

    @Test func keepsOnlyTheStateInAlphabeticalOrder() {
        let ballots = RepresentativeBallots(
            detail: detail([
                ballot("Zeca", "sp", "Não"), ballot("Ana", "sp", "Sim"), ballot("Rui", "mg", "Sim"),
            ]), uf: "SP")
        #expect(ballots.uf == "sp")
        #expect(ballots.ballots.map(\.name) == ["Ana", "Zeca"])
        #expect(ballots.body.contains("Ana (PSD): Sim"))
        #expect(ballots.body.contains("Zeca (PSD): Não"))
        #expect(!ballots.body.contains("Rui"))
        #expect(ballots.dialog.hasPrefix("PL 1873/2026"))
    }

    @Test func countsChoicesWithYesAndNoFirst() {
        let ballots = RepresentativeBallots(
            detail: detail([
                ballot("A", "sp", "Ausente"), ballot("B", "sp", "Não"), ballot("C", "sp", "Sim"),
                ballot("D", "sp", "Sim"), ballot("E", "sp", "Abstenção"),
            ]), uf: "sp")
        #expect(ballots.counts.map(\.choice) == ["Sim", "Não", "Abstenção", "Ausente"])
        #expect(ballots.counts.first?.count == 2)
        #expect(ballots.body.contains("Sim \(PublicFormat.number(2))"))
    }

    @Test func saysWhenNobodyFromTheStateVoted() {
        let ballots = RepresentativeBallots(detail: detail([ballot("Rui", "mg", "Sim")]), uf: "ac")
        #expect(ballots.ballots.isEmpty)
        #expect(ballots.counts.isEmpty)
        #expect(ballots.body.contains("AC"))
    }
}

struct IntegrationActionsTests {
    private let now = Date(timeIntervalSince1970: 1_792_917_720)

    private func actions(_ scenario: PublicDataScenario) -> IntegrationActions {
        IntegrationActions(service: ShowcasePublicData(scenario: scenario, now: now))
    }

    @Test func findsTheLatestRollCallVoteForAState() async throws {
        let result = try #require(try await actions(.normal).latestVote(uf: "sp"))
        #expect(result.uf == "sp")
        #expect(result.ballots.allSatisfy { $0.uf == "sp" })
        let names = result.ballots.map(\.name)
        #expect(names == names.sorted { $0.localizedStandardCompare($1) == .orderedAscending })
    }

    @Test func hasNoVoteWhenNothingWasPublished() async throws {
        #expect(try await actions(.empty).latestVote(uf: "sp") == nil)
        await #expect(throws: PublicDataError.offline) {
            try await actions(.offline).latestVote(uf: "sp")
        }
    }

    @Test func searchesPeopleIgnoringAccentsInAlphabeticalOrder() async throws {
        let found = try await actions(.normal).people(matching: "tarcisio")
        #expect(found.map(\.slug) == ["tarcisio-de-freitas"])
        #expect(try await actions(.normal).people(matching: "  ").isEmpty)
        let many = try await actions(.normal).people(matching: "a")
        #expect(many.count <= IntegrationActions.searchLimit)
        let names = many.map(\.name)
        #expect(names == names.sorted { $0.localizedStandardCompare($1) == .orderedAscending })
    }

    @Test func resolvesSlugsInTheGivenOrder() async throws {
        let people = try await actions(.normal).people(slugs: ["kim-kataguiri", "nope", "lula"])
        #expect(people.map(\.slug) == ["kim-kataguiri", "lula"])
    }
}

struct SpotlightPersonTests {
    private func card(_ slug: String, office: Office = .federalDeputy, uf: String = "sp")
        -> PersonCard
    {
        PersonCard(
            slug: slug, name: "Nome \(slug)", office: office, uf: uf, party: "PSB", photo: nil,
            status: .inOffice)
    }

    @Test func describesNameOfficePartyAndState() {
        let person = SpotlightPerson(card("tabata-amaral"))
        #expect(person.id == "tabata-amaral")
        #expect(person.title == "Nome tabata-amaral")
        #expect(person.detail == "\(Office.federalDeputy.title) · PSB · SP")
        #expect(person.keywords.contains("SP"))
        #expect(person.keywords.contains(HomePlace.name(of: "sp")))
        #expect(person.url?.absoluteString == "fiscal://person/tabata-amaral")
    }

    @Test func leavesTheCountryOutOfTheDetail() {
        let person = SpotlightPerson(card("lula", office: .president, uf: "br"))
        #expect(person.detail == "\(Office.president.title) · PSB")
    }

    @Test func listsFollowedAndRecentOnce() {
        let entries = SpotlightPerson.entries(
            followed: [card("a"), card("b")], recent: [card("b"), card("c"), card("")])
        #expect(entries.map(\.id) == ["a", "b", "c"])
    }
}

struct RecentPeopleTests {
    @Test func keepsTheLatestFirstWithoutRepeats() throws {
        let suite = "fiscal.tests.recent.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let recent = RecentPeople(defaults: defaults)
        #expect(recent.record("a"))
        #expect(recent.record("b"))
        #expect(!recent.record("b"))
        #expect(recent.record("a"))
        #expect(recent.slugs == ["a", "b"])
        #expect(!recent.record(""))
        for index in 0..<(RecentPeople.limit + 5) { recent.record("p\(index)") }
        #expect(recent.slugs.count == RecentPeople.limit)
        recent.clear()
        #expect(recent.slugs.isEmpty)
    }

    @Test func findsPeopleInRoutes() {
        let routes: [Route] = [.vote(id: "v"), .person(slug: "a"), .races, .person(slug: "b")]
        #expect(RecentPeople.personSlugs(in: routes) == ["a", "b"])
    }
}
