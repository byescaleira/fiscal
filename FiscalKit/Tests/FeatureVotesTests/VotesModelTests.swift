import FiscalData
import FiscalDomain
import Foundation
import Testing

@testable import FeatureVotes

struct StoredLens: LensRepository {
    let value: Lens?

    func lens() async throws -> Lens? { value }
    func save(_ lens: Lens) async throws {}
    func reset() async throws {}
}

@MainActor
struct VotesModelTests {
    private let now = Date(timeIntervalSince1970: 1_792_917_720)

    private func model(
        _ scenario: PublicDataScenario = .normal, lens: Lens? = nil
    ) -> VotesModel {
        let now = now
        return VotesModel(
            service: ShowcasePublicData(scenario: scenario, now: now),
            lens: StoredLens(value: lens), now: { now })
    }

    @Test func loadsTheLatestFloorVotesGroupedByDay() async throws {
        let votes = model()
        await votes.load()
        #expect(votes.phase == .loaded)
        #expect(votes.votes.count == 6)
        let days = votes.days
        #expect(days.map(\.id) == days.map(\.id).sorted(by: >))
        #expect(days.flatMap(\.votes).count == 6)
        for day in days {
            #expect(day.votes.allSatisfy { $0.date == day.id })
        }
        let first = try #require(days.first)
        #expect(votes.dayTitle(first) == String(appLocalized: "Yesterday"))
        #expect(votes.sourceText(first).contains(House.camara.title))
    }

    @Test func filtersByHouseAndByTopic() async {
        let votes = model()
        await votes.load()
        votes.house = .senado
        #expect(!votes.filtered.isEmpty)
        #expect(votes.filtered.allSatisfy { $0.house == .senado })
        votes.toggle(.security)
        #expect(votes.filtered.isEmpty)
        #expect(votes.days.isEmpty)
        #expect(votes.hasFilter)
        votes.clearFilters()
        votes.toggle(.security)
        #expect(votes.filtered.map(\.proposition) == ["PL 3051/2026"])
        votes.toggle(.security)
        #expect(votes.theme == nil)
    }

    @Test func theLensPutsItsTopicsFirstWithoutHidingAnything() async {
        let lens = Lens(themes: [.security, .health, .environment], stance: .right)
        let votes = model(lens: lens)
        await votes.load()
        #expect(Array(votes.themeChoices.prefix(3)) == [.security, .health, .environment])
        #expect(Set(votes.themeChoices).count == votes.themeChoices.count)
        #expect(votes.lensStance == .right)
        #expect(votes.highlights.count == VotesModel.highlightLimit)
        #expect(votes.highlights.allSatisfy { $0.themes.contains(where: lens.contains) })
        #expect(votes.filtered.count == 6)
        votes.house = .camara
        #expect(votes.highlights.isEmpty)
    }

    @Test func withoutALensNothingIsAdapted() async {
        let votes = model()
        await votes.load()
        #expect(votes.lensStance == nil)
        #expect(votes.highlights.isEmpty)
        #expect(votes.themeChoices == Theme.allCases.filter { votes.themeChoices.contains($0) })
    }

    @Test func aLensWithoutASideReadsAsImpartial() async {
        let votes = model(lens: Lens(themes: [.health, .education, .taxes]))
        await votes.load()
        #expect(votes.lensStance?.effective == .impartial)
    }

    @Test func theAgendaShowsTheHousesWithItems() async throws {
        let votes = model()
        await votes.load()
        #expect(votes.agendaHouses.map(\.house) == [.camara, .senado])
        #expect(votes.isAgendaToday)
        let camara = try #require(votes.agendaHouses.first)
        #expect(!votes.agendaStatus(camara).isEmpty)
    }

    @Test func missingTalliesShowADash() async {
        let votes = model()
        let vote = VoteSummary(
            id: "camara-1", house: .camara, date: CalendarDay(now), time: nil,
            proposition: "PL 1/2026", kind: nil, summary: "Texto", plainSummary: nil,
            themes: [], result: nil, approved: nil, nominal: false,
            tally: VoteSummary.Tally(yes: nil, no: nil, others: nil))
        #expect(votes.yesText(vote) == PublicFormat.missing)
        #expect(votes.noText(vote) == PublicFormat.missing)
        #expect(VoteOutcome(vote) == .symbolic)
        #expect(VoteTally.segments(vote.tally).allSatisfy { $0.value == 0 })
    }

    @Test func noVotesIsAnHonestEmptyState() async {
        let votes = model(.empty)
        await votes.load()
        #expect(votes.phase == .loaded)
        #expect(votes.isEmpty)
    }

    @Test func offlineSaysSo() async {
        let votes = model(.offline)
        await votes.load()
        #expect(votes.phase == .failed(.offline))
        #expect(votes.isEmpty)
    }
}
