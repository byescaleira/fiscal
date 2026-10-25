import FiscalData
import FiscalDomain
import Foundation
import Testing

@testable import FeatureSearch

@MainActor
struct SearchModelThemesTests {
    private let now = Date(timeIntervalSince1970: 1_792_917_720)

    private func model(_ scenario: PublicDataScenario) -> SearchModel {
        let now = now
        return SearchModel(
            service: ShowcasePublicData(scenario: scenario, now: now),
            recents: MemoryRecentSearches(), now: { now })
    }

    @Test func showsLoadingUntilTheVotesArrive() async {
        let search = model(.normal)
        #expect(search.isLoadingThemes)
        #expect(search.themeActivity == nil)
        await search.load()
        #expect(!search.isLoadingThemes)
    }

    @Test func chartsTheRecentVotesByTopic() async throws {
        let search = model(.normal)
        await search.load()
        let activity = try #require(search.themeActivity)
        #expect(activity.total == 6)
        #expect(
            activity.slices.map(\.theme).sorted { $0.rawValue < $1.rawValue }
                == SearchModel.defaultThemes.sorted { $0.rawValue < $1.rawValue })
        #expect(activity.leader?.theme == .economy)
        #expect(activity.leader?.count == 2)
        #expect(activity.grain == .day)
        #expect(activity.periods.map(\.count).reduce(0, +) == 5)
        #expect(!search.headline(for: activity).isEmpty)
    }

    @Test func emptyDataKeepsTheTopicsWithoutAChart() async throws {
        let search = model(.empty)
        await search.load()
        let activity = try #require(search.themeActivity)
        #expect(!activity.hasVotes)
        #expect(activity.periods.isEmpty)
    }

    @Test func offlineHasNoChartAndStopsLoading() async {
        let search = model(.offline)
        await search.load()
        #expect(search.themeActivity == nil)
        #expect(!search.isLoadingThemes)
    }

    @Test func approvedCountShowsOnlyWhenSomeVotesWereNotApproved() {
        let search = model(.normal)
        let all = ThemeActivity.Slice(theme: .health, slot: 0, count: 2, approved: 2, rejected: 0)
        let some = ThemeActivity.Slice(theme: .health, slot: 0, count: 3, approved: 2, rejected: 1)
        let none = ThemeActivity.Slice(theme: .health, slot: 0, count: 1, approved: 0, rejected: 1)
        #expect(search.approvedText(for: all) == nil)
        #expect(search.approvedText(for: some) != nil)
        #expect(search.approvedText(for: none) == nil)
    }

    @Test func tappingATopicFiltersItsVotes() async {
        let search = model(.normal)
        await search.load()
        search.apply(.theme(.economy))
        #expect(search.tokens == [.theme(.economy)])
        #expect(search.results.votes.count == 2)
    }
}
