import FeatureCore
import FiscalData
import FiscalDomain
import Foundation
import Testing

@testable import FeatureVotes

struct SingleVote: PublicDataService {
    let detail: VoteDetail

    func meta() async throws -> PublicMeta { throw PublicDataError.notFound }
    func people() async throws -> [PersonCard] { [] }
    func places() async throws -> [Place] { [] }
    func representatives(uf: String) async throws -> PlaceRepresentatives {
        throw PublicDataError.notFound
    }
    func profile(slug: String) async throws -> Profile { throw PublicDataError.notFound }
    func votes(slug: String, year: Int) async throws -> PublicList<PersonVote> {
        throw PublicDataError.notFound
    }
    func proposals(slug: String, year: Int) async throws -> PublicList<Proposal> {
        throw PublicDataError.notFound
    }
    func speeches(slug: String, year: Int) async throws -> PublicList<Speech> {
        throw PublicDataError.notFound
    }
    func expenses(slug: String, year: Int) async throws -> ExpenseList {
        throw PublicDataError.notFound
    }
    func recentVotes() async throws -> [VoteSummary] { [detail.vote] }
    func vote(id: String) async throws -> VoteDetail { detail }
    func agenda() async throws -> Agenda { throw PublicDataError.notFound }
    func money() async throws -> MoneyOverview { throw PublicDataError.notFound }
    func today() async throws -> TodayDigest { throw PublicDataError.notFound }
    func checks(slug: String) async throws -> FactCheckList? { nil }
}

@MainActor
struct VoteDetailModelTests {
    private let now = Date(timeIntervalSince1970: 1_792_917_720)

    private func loaded(
        _ id: String = "camara-18732026", lens: Lens? = nil, homeUF: String? = nil
    ) async -> VoteDetailModel {
        let model = VoteDetailModel(
            id: id, service: ShowcasePublicData(scenario: .normal, now: now),
            lens: StoredLens(value: lens), homeUF: homeUF)
        await model.load()
        return model
    }

    @Test func theScoreboardShowsTheOfficialTally() async {
        let vote = await loaded()
        #expect(vote.phase == .loaded)
        #expect(vote.title == "PL 1873/2026")
        #expect(vote.yesText == "412")
        #expect(vote.noText == "61")
        #expect(vote.outcome == .approved)
        #expect(vote.requiredYes == nil)
        #expect(!vote.sourceText.isEmpty)
    }

    @Test func theRollCallAddsUpToTheWholeChamber() async {
        let vote = await loaded()
        let people = vote.detail?.people ?? []
        #expect(people.count == 513)
        #expect(Set(people.map(\.id)).count == people.count)
        #expect(vote.count(.yes) == 412)
        #expect(vote.count(.no) == 61)
        #expect(vote.count(.other) == 9)
        #expect(vote.count(.absent) == 31)
        #expect(people.contains { $0.slug == nil })
    }

    @Test func partiesAreOrderedByBenchSizeNeverByHowTheyVoted() async {
        let vote = await loaded()
        let rows = vote.partyRows
        #expect(rows.first?.party == "PL")
        #expect(rows.map(\.total) == rows.map(\.total).sorted(by: >))
        #expect(rows.reduce(0) { $0 + $1.total } == 513)
        #expect(vote.largestBench == rows.first?.total)
        for pair in zip(rows, rows.dropFirst()) where pair.0.total == pair.1.total {
            #expect(pair.0.party.localizedStandardCompare(pair.1.party) == .orderedAscending)
        }
    }

    @Test func theRollCallIsAlphabeticalAndSearchable() async {
        let vote = await loaded()
        let names = vote.ballots.map(\.name)
        #expect(names == names.sorted { $0.localizedStandardCompare($1) == .orderedAscending })
        vote.searchText = "erika"
        #expect(vote.ballots.map(\.slug) == ["erika-hilton"])
        vote.searchText = "Sergio"
        #expect(vote.ballots.isEmpty)
        vote.searchText = ""
        vote.ballotFilter = .no
        #expect(vote.ballots.allSatisfy { BallotChoice(vote: $0.vote) == .no })
        vote.ballotFilter = .all
        vote.select(party: "PSOL")
        #expect(vote.ballots.allSatisfy { $0.party == "PSOL" })
        vote.select(party: "PSOL")
        #expect(vote.party == nil)
    }

    @Test func yourRepresentativesComeFromTheChosenState() async {
        let without = await loaded()
        #expect(without.representatives == nil)
        let vote = await loaded(homeUF: "SP")
        let people = vote.representatives ?? []
        #expect(people.count == 70)
        #expect(people.allSatisfy { $0.uf == "sp" })
        #expect(people.contains { $0.slug == "tabata-amaral" })
        #expect(vote.representativesTitle.contains("SP"))
    }

    @Test func guidanceListsYesFirstAndPartiesAlphabetically() async {
        let vote = await loaded()
        let groups = vote.guidanceGroups
        #expect(!groups.isEmpty)
        #expect(groups.first?.choice == .yes)
        for group in groups {
            #expect(
                group.parties
                    == group.parties.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            )
        }
        let senate = await loaded("senado-22902026")
        #expect(senate.guidanceGroups.isEmpty)
    }

    @Test func anAmendmentSaysHowManyYesVotesItNeeds() async {
        let vote = await loaded("senado-142026")
        #expect(vote.isAmendment)
        #expect(vote.requiredYes == 49)
        #expect(vote.headline.contains("49"))
    }

    @Test func theLensOnlyMarksTheTopics() async {
        let vote = await loaded(lens: Lens(themes: [.economy, .health, .security], stance: .left))
        #expect(vote.themes == [.economy, .taxes])
        #expect(vote.lensStance == .left)
        #expect(vote.yesText == "412")
        let other = await loaded(lens: Lens(themes: [.health, .security, .culture], stance: .left))
        #expect(other.lensStance == nil)
    }

    @Test func aBallotWithoutSlugAndAMissingTallyStayHonest() async {
        let summary = VoteSummary(
            id: "senado-1", house: .senado, date: CalendarDay(now), time: nil,
            proposition: "PL 1/2026", kind: nil, summary: "Texto oficial", plainSummary: nil,
            themes: [], result: nil, approved: nil, nominal: false,
            tally: VoteSummary.Tally(yes: nil, no: nil, others: nil))
        let detail = VoteDetail(
            vote: summary, quorum: nil, guidance: [],
            parties: [VoteDetail.PartyTally(party: "PT", yes: 2, no: 1, others: 0)],
            people: [
                VoteDetail.Ballot(slug: nil, name: "Zé Ninguém", party: "PT", uf: "ba", vote: "Sim")
            ], sources: [])
        let vote = VoteDetailModel(id: "senado-1", service: SingleVote(detail: detail))
        await vote.load()
        #expect(vote.yesText == PublicFormat.missing)
        #expect(vote.quorumText.contains(PublicFormat.missing))
        #expect(vote.outcome == .symbolic)
        #expect(vote.ballots.first?.slug == nil)
        #expect(vote.partyRows.first?.yes == 1)
        #expect(vote.plainSummary == nil)
        #expect(vote.officialSummary == "Texto oficial")
    }

    @Test func aMissingVoteSaysSo() async {
        let vote = await loaded("missing")
        #expect(vote.phase == .failed(.notFound))
        #expect(vote.isEmpty)
    }
}
