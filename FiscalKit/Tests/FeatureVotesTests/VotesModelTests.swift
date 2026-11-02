import FiscalData
import FiscalDomain
import Foundation
import Testing

@testable import FeatureVotes

@MainActor
struct VotesModelTests {
    private let now = Date(timeIntervalSince1970: 1_792_917_720)

    private func model(_ scenario: PublicDataScenario = .normal) -> VotesModel {
        let now = now
        return VotesModel(
            service: ShowcasePublicData(scenario: scenario, now: now), now: { now })
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
        #expect(votes.activeFilterCount == 0)
        votes.house = .senado
        #expect(!votes.filtered.isEmpty)
        #expect(votes.filtered.allSatisfy { $0.house == .senado })
        #expect(votes.activeFilterCount == 1)
        votes.theme = .security
        #expect(votes.filtered.isEmpty)
        #expect(votes.days.isEmpty)
        #expect(votes.showsNoMatch)
        #expect(votes.hasFilter)
        #expect(votes.activeFilterCount == 2)
        votes.clearFilters()
        #expect(!votes.hasFilter)
        #expect(votes.theme == nil)
        votes.theme = .security
        #expect(votes.filtered.map(\.proposition) == ["PL 3051/2026"])
    }

    @Test func theSubtitleSaysWhichFiltersAreOn() async {
        let votes = model()
        await votes.load()
        let allTopics = String(appLocalized: "All Topics")
        #expect(votes.filterSummary == "\(VotesModel.HouseFilter.all.title) · \(allTopics)")
        votes.house = .camara
        votes.theme = .health
        #expect(
            votes.filterSummary
                == "\(VotesModel.HouseFilter.camara.title) · \(Theme.health.title)")
    }

    @Test func theTopicMenuKeepsTheNaturalOrder() async {
        let votes = model()
        await votes.load()
        #expect(!votes.themeChoices.isEmpty)
        #expect(votes.themeChoices == Theme.allCases.filter { votes.themeChoices.contains($0) })
        #expect(Set(votes.themeChoices).count == votes.themeChoices.count)
    }

    @Test func everyVoteIsListedInItsDayWithNothingPutFirst() async {
        let votes = model()
        await votes.load()
        #expect(votes.filtered.count == 6)
        let listed = votes.days.flatMap(\.votes).map(\.id)
        #expect(listed.count == Set(listed).count)
        #expect(Set(listed) == Set(votes.filtered.map(\.id)))
        #expect(!votes.showsNoMatch)
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
