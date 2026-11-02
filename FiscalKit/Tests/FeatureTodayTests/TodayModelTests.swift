import FiscalData
import FiscalDomain
import Foundation
import Testing

@testable import FeatureToday

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct TodayModelTests {
    private let now = Date(timeIntervalSince1970: 1_792_917_720)
    private let afterTheResult = Date(timeIntervalSince1970: 1_792_963_200)

    private func model(
        _ scenario: PublicDataScenario = .normal, races: RaceScenario? = nil,
        follows: PublicDataScenario? = nil, clock: Date? = nil
    ) -> TodayModel {
        let today = clock ?? now
        return TodayModel(
            service: ShowcasePublicData(scenario: scenario, now: now),
            races: races.map(ShowcaseLiveResults.init(scenario:)),
            follows: follows.map { ShowcaseFollowRepository(scenario: $0, now: now) },
            raceInterval: .milliseconds(1), now: { today })
    }

    @Test func loadsTheDigestOfTheDay() async {
        let model = TodayModel(service: ShowcasePublicData(scenario: .normal, now: now))
        #expect(model.phase == .idle)
        await model.load()
        #expect(model.phase == .loaded)
        #expect(!model.isEmpty)
        #expect(model.events.first?.kind == .vote)
        #expect(!model.sources.isEmpty)
        #expect(model.digestSource != nil)
        #expect(model.agendaSource != nil)
        #expect(model.recentSource != nil)
    }

    @Test func theDayKeepsTheOrderOfTheData() async throws {
        let service = ShowcasePublicData(scenario: .normal, now: now)
        let digest = try await service.today()
        let highlights = try await service.highlights()
        let model = TodayModel(service: service)
        await model.load()
        #expect(model.events == digest.events)
        #expect(model.briefing == digest.events)
        #expect(model.lead == digest.events.first)
        #expect(model.orderedHighlights == highlights?.items ?? [])
    }

    @Test func theLeadVoteIsNotRepeatedInRecentVotes() async throws {
        let model = model()
        await model.load()
        let lead = try #require(model.lead)
        let vote = try #require(model.leadVote(for: lead))
        #expect(!model.recent.contains(vote))
        #expect(model.recent.count == TodayModel.recentLimit)
        #expect(model.route(for: lead) == .vote(id: vote.id))
        #expect(model.shareSubject(for: lead) == .vote(id: vote.id))
    }

    @Test func aLiveRaceTakesTheCardAndLeavesTheSummary() async {
        let model = model(races: .close)
        await model.load()
        #expect(model.liveBoard?.race.id == "presidente-br")
        #expect(model.liveBoard?.others == 6)
        #expect(!model.briefing.contains { $0.kind == .race })
        #expect(model.events.contains { $0.kind == .race })
    }

    @Test func noElectionNoCard() async {
        let finished = model(
            races: .finished, clock: afterTheResult.addingTimeInterval(TodayRaceBoard.winnerWindow))
        await finished.load()
        #expect(finished.liveBoard == nil)
        #expect(finished.briefing.contains { $0.kind == .race })
        await finished.watchRaces()
        let quiet = model()
        await quiet.load()
        #expect(quiet.liveBoard == nil)
    }

    @Test func theWinnerStaysForADayWithoutPolling() async {
        let finished = model(races: .finished, clock: afterTheResult)
        await finished.load()
        #expect(finished.liveBoard?.race.final == true)
        #expect(finished.liveBoard?.race.office == .president)
        await finished.watchRaces()
        #expect(finished.liveBoard?.race.final == true)
    }

    @Test func aLostConnectionKeepsTheLastNumbersMarkedAsStale() async {
        let model = model(races: .offline)
        await model.load()
        #expect(model.liveBoard?.isStale == false)
        await model.refreshRaces()
        #expect(model.racesOffline)
        #expect(model.liveBoard?.isStale == true)
    }

    @Test func pointsToFollowingWithTheNumberOfUpdates() async {
        let model = model(follows: .normal)
        await model.load()
        #expect(model.followedCount == 5)
        #expect(model.followingTitle(newCount: 3) == "3 updates from who you follow")
        #expect(model.followingTitle(newCount: 0) == "Who you follow")
        let empty = self.model()
        await empty.load()
        #expect(empty.followedCount == 0)
        #expect(empty.followingTitle(newCount: 3) == "Follow who represents you")
    }

    @Test func anEmptyDayIsHonest() async {
        let model = model(.empty)
        await model.load()
        #expect(model.phase == .loaded)
        #expect(model.isEmpty)
        #expect(model.lead == nil)
        #expect(model.houses.isEmpty)
        #expect(model.recent.isEmpty)
        #expect(model.agendaSource == nil)
        #expect(model.followedCount == 0)
    }

    @Test func reportsWhyTheDayDidNotLoad() async {
        let offline = model(.offline)
        await offline.load()
        #expect(offline.phase == .failed(.offline))
        #expect(!offline.hasLoadedDigest)
        #expect(offline.notice == nil)
        let unavailable = model(.unavailable)
        await unavailable.load()
        #expect(unavailable.phase == .failed(.unavailable))
        let missing = TodayModel(service: nil)
        await missing.load()
        #expect(missing.phase.error == .unavailable)
    }

    @Test func writesTheDayTextsInTheModel() async throws {
        let model = model()
        await model.load()
        #expect(model.dateKicker == model.dateLine.uppercased())
        let house = try #require(model.houses.first)
        #expect(model.shownItems(house).count == min(house.items.count, TodayModel.agendaLimit))
        #expect(
            (model.moreOnAgendaText(house) != nil) == (house.items.count > TodayModel.agendaLimit))
        #expect(!model.nextSessionText(house.day).isEmpty)
        let vote = try #require(model.recent.first)
        #expect(model.voteLine(vote).hasPrefix(vote.house.title))
        #expect(model.failureTitle(.offline) == PublicDataError.offline.title)
        #expect(model.failureTitle(.unavailable) == "Couldn't load the summary of the day")
        #expect(model.kindKicker(.vote) == "VOTE")
    }

    @Test func longNamesStillLoad() async {
        let model = model(.longNames, follows: .longNames)
        await model.load()
        #expect(model.phase == .loaded)
        #expect(model.followedCount > 0)
    }
}
