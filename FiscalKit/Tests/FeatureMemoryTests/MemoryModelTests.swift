import FeatureCore
import FiscalDomain
import Foundation
import Testing

@testable import FeatureMemory

@MainActor
struct MemoryModelTests {
    private func model(
        _ service: (any PublicDataService)?, races: (any LiveResultsService)? = nil,
        on date: Date
    ) -> MemoryModel {
        MemoryModel(service: service, races: races, now: { date })
    }

    private func betweenRounds() throws -> Date { try MemoryFixture.day(2_026, 10, 10) }

    private func secondRound() throws -> Date { try MemoryFixture.day(2_026, 10, 25) }

    @Test func loadsElectionsPeriodsAndGuides() async throws {
        let model = model(try MemoryFixture.service(), on: try betweenRounds())
        #expect(model.phase == .idle)
        await model.load()
        #expect(model.phase == .loaded)
        #expect(!model.isEmpty)
        #expect(model.presidential.map(\.year) == [2_022, 2_018])
        #expect(model.otherYears == [2_014])
        #expect(model.periods.map(\.id) == ["first-republic", "vargas-era", "new-republic"])
        #expect(model.guides.map(\.id) == ["how-voting-works"])
        #expect(model.republicYears == 2_026 - MemoryModel.republicStart)
    }

    @Test func keepsOnlyTheElectedAwaitingInAlphabeticalOrder() async throws {
        let model = model(try MemoryFixture.service(), on: try betweenRounds())
        await model.load()
        #expect(model.awaiting.map(\.slug) == ["alvaro", "zelia"])
        #expect(model.awaiting.allSatisfy { $0.status == .electedAwaiting })
    }

    @Test func theWinnerIsTheElectedPickEvenWhenListedSecond() async throws {
        let model = model(try MemoryFixture.service(), on: try betweenRounds())
        await model.load()
        let race = try #require(model.presidential.first { $0.year == 2_022 })
        #expect(model.winner(of: race)?.ballotName == "LULA")
        #expect(model.runnerUp(of: race)?.ballotName == "BOLSONARO")
    }

    @Test func withoutAnElectedFlagTheFirstPickWinsAndTheNextIsRunnerUp() async throws {
        let model = model(try MemoryFixture.service(), on: try betweenRounds())
        await model.load()
        let race = try #require(model.presidential.first { $0.year == 2_018 })
        #expect(race.finalRound?.leaders.allSatisfy { !$0.elected } == true)
        #expect(model.winner(of: race)?.ballotName == "BOLSONARO")
        #expect(model.runnerUp(of: race)?.ballotName == "HADDAD")
    }

    @Test func aRaceWithASinglePickHasNoRunnerUp() async throws {
        let history = try MemoryFixture.history()
        let model = model(try MemoryFixture.service(), on: try betweenRounds())
        let race = try #require(history.races.first { $0.office == .governor })
        #expect(model.winner(of: race)?.ballotName == "ALCKMIN")
        #expect(model.runnerUp(of: race) == nil)
    }

    @Test func onElectionDayTheCountComesFromThePresidentialRace() async throws {
        let feed = RaceFeed(list: [
            MemoryFixture.race("governador-sp", office: .governor, counted: 80),
            MemoryFixture.race("presidente-br", office: .president, counted: 42.5),
        ])
        let model = model(try MemoryFixture.service(), races: feed, on: try secondRound())
        await model.load()
        #expect(model.liveCounted == 0.425)
    }

    @Test func withoutAPresidentialRaceTheFirstRaceGivesTheCount() async throws {
        let feed = RaceFeed(list: [
            MemoryFixture.race("governador-sp", office: .governor, counted: 64)
        ])
        let model = model(try MemoryFixture.service(), races: feed, on: try secondRound())
        await model.load()
        #expect(model.liveCounted == 0.64)
    }

    @Test func outsideElectionDayTheCountIsNotFetched() async throws {
        let feed = RaceFeed(list: [
            MemoryFixture.race("presidente-br", office: .president, counted: 42.5)
        ])
        let model = model(try MemoryFixture.service(), races: feed, on: try betweenRounds())
        await model.load()
        #expect(model.liveCounted == nil)
    }

    @Test func aFailingOrEmptyCountLeavesTheScheduleAlone() async throws {
        let failing = model(
            try MemoryFixture.service(), races: RaceFeed(fails: true), on: try secondRound())
        let empty = model(try MemoryFixture.service(), races: RaceFeed(), on: try secondRound())
        await failing.load()
        await empty.load()
        #expect(failing.liveCounted == nil)
        #expect(empty.liveCounted == nil)
        #expect(failing.phase == .loaded)
    }

    @Test func aFailingServiceShowsNotFound() async throws {
        let model = model(MemoryService.failing, on: try betweenRounds())
        await model.load()
        #expect(model.phase == .failed(.notFound))
        #expect(model.isEmpty)
        #expect(model.awaiting.isEmpty)
    }

    @Test func partialDataStillLoads() async throws {
        let service = MemoryService(timeline: try MemoryFixture.timeline())
        let model = model(service, on: try betweenRounds())
        await model.load()
        #expect(model.phase == .loaded)
        #expect(model.presidential.isEmpty)
        #expect(model.periods.count == 3)
    }

    @Test func withoutAServiceItIsUnavailable() async throws {
        let model = model(nil, on: try betweenRounds())
        await model.load()
        #expect(model.phase == .failed(.unavailable))
    }
}
