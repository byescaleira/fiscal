import FeatureCore
import FiscalData
import FiscalDomain
import Foundation
import Testing

@testable import FeatureFeed

@MainActor
struct FeedTopAndDatesTests {
    private let now = Date(timeIntervalSince1970: 1_792_917_720)
    private let afterTheResult = Date(timeIntervalSince1970: 1_792_963_200)

    private func raceModel(_ races: RaceScenario? = nil, clock: Date? = nil) -> FeedModel {
        let today = clock ?? now
        return FeedModel(
            service: ShowcasePublicData(scenario: .normal, now: now),
            races: races.map(ShowcaseLiveResults.init(scenario:)), follows: nil,
            raceInterval: .milliseconds(1),
            seen: FollowingSeenStore(suiteName: "feed-\(UUID().uuidString)"),
            regionUF: { nil }, now: { today }, publishesSnapshot: false)
    }

    @Test func aMonthOfSpendingShowsTheMonthAndNotADay() throws {
        let model = raceModel()
        let day = try #require(CalendarDay(year: 2_026, month: 11, day: 1))
        let item = FeedItem(
            id: "x", kind: .expenses, date: day, title: "", reason: .relevant,
            expenses: FeedExpenses(slug: "a", year: 2_026, month: 11, cents: 100))
        #expect(model.dayText(item).contains("2026"))
        #expect(!model.dayText(item).hasPrefix("1 "))
    }

    @Test func aCardThatOpensTheSourceSaysSo() throws {
        let model = raceModel()
        let day = try #require(CalendarDay(year: 2_026, month: 5, day: 20))
        let check = FeedItem(
            id: "a", kind: .check, date: day, title: "Fato", reason: .relevant,
            url: URL(string: "https://example.com"))
        let plain = FeedItem(id: "b", kind: .event, date: day, title: "Fato", reason: .relevant)
        #expect(model.accessibility(check).contains("See the Source"))
        #expect(!model.accessibility(plain).contains("See the Source"))
    }

    @Test func aFactFromAnotherYearShowsTheYear() throws {
        let model = raceModel()
        let thisYear = FeedItem(
            id: "a", kind: .check, date: try #require(CalendarDay(year: 2_026, month: 5, day: 20)),
            title: "", reason: .relevant)
        let older = FeedItem(
            id: "b", kind: .check, date: try #require(CalendarDay(year: 2_025, month: 5, day: 20)),
            title: "", reason: .relevant)
        #expect(!model.dayText(thisYear).contains("2026"))
        #expect(model.dayText(older).contains("2025"))
    }

    @Test func aLiveRaceTakesTheTop() async {
        let model = raceModel(.close)
        await model.load()
        #expect(model.liveBoard?.race.id == "presidente-br")
        #expect(model.liveBoard?.others == 6)
    }

    @Test func noElectionNoCard() async {
        let finished = raceModel(
            .finished, clock: afterTheResult.addingTimeInterval(FeedRaceBoard.winnerWindow))
        await finished.load()
        #expect(finished.liveBoard == nil)
        await finished.watchRaces()
        let quiet = raceModel()
        await quiet.load()
        #expect(quiet.liveBoard == nil)
    }

    @Test func theWinnerStaysForADayWithoutPolling() async {
        let finished = raceModel(.finished, clock: afterTheResult)
        await finished.load()
        #expect(finished.liveBoard?.race.final == true)
        await finished.watchRaces()
        #expect(finished.liveBoard?.race.final == true)
    }

    @Test func aLostConnectionKeepsTheLastNumbersMarkedAsStale() async {
        let model = raceModel(.offline)
        await model.load()
        #expect(model.liveBoard?.isStale == false)
        await model.refreshRaces()
        #expect(model.racesOffline)
        #expect(model.liveBoard?.isStale == true)
    }

    @Test func theLeadHighlightIsPinnedAndNotRepeated() async throws {
        let model = raceModel()
        await model.load()
        let lead = try #require(model.highlightLead)
        #expect(!model.items.contains { $0.id == "highlight-\(lead.id)" || $0.id == lead.id })
        #expect(model.highlightHeroOverline(lead) == model.highlightHeroOverline(lead).uppercased())
    }
}
