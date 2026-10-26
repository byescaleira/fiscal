import FiscalDomain
import Foundation
import Testing

@testable import FeatureMemory

struct ElectionScheduleTests {
    private let brasilia: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo") ?? .gmt
        return calendar
    }()

    private func election(_ year: Int, at date: Date) throws -> ScheduledElection {
        try #require(
            ElectionSchedule.elections(now: date, calendar: brasilia).first { $0.year == year })
    }

    @Test func listsEveryGeneralElectionNewestFirstWithTwoRounds() throws {
        let now = try MemoryFixture.day(2_026, 10, 10, calendar: brasilia)
        let elections = ElectionSchedule.elections(now: now, calendar: brasilia)
        #expect(elections.map(\.year) == [2_026, 2_022, 2_018])
        #expect(elections.allSatisfy { $0.rounds.map(\.number) == [1, 2] })
        #expect(elections.map(\.isCurrent) == [true, false, false])
    }

    @Test func betweenRoundsTheFirstIsDoneAndTheSecondIsUpcoming() throws {
        let current = try election(2_026, at: MemoryFixture.day(2_026, 10, 10, calendar: brasilia))
        #expect(current.rounds.map(\.status) == [.past, .upcoming])
        #expect(current.liveRound == nil)
        #expect(!current.isFinished)
    }

    @Test func onElectionDayTheRoundIsLive() throws {
        let current = try election(2_026, at: MemoryFixture.day(2_026, 10, 25, calendar: brasilia))
        #expect(current.rounds.map(\.status) == [.past, .today])
        #expect(current.liveRound?.number == 2)
        #expect(!current.isFinished)
    }

    @Test func beforeTheFirstRoundBothRoundsAreUpcoming() throws {
        let current = try election(2_026, at: MemoryFixture.day(2_026, 9, 1, calendar: brasilia))
        #expect(current.rounds.map(\.status) == [.upcoming, .upcoming])
    }

    @Test func pastElectionsAreFinished() throws {
        let past = try election(2_022, at: MemoryFixture.day(2_026, 10, 25, calendar: brasilia))
        #expect(past.isFinished)
        #expect(past.liveRound == nil)
        #expect(!past.isCurrent)
    }

    @Test func theRoundTurnsLiveAtMidnightAndPastTheNextMidnight() throws {
        let eve = try election(
            2_026, at: MemoryFixture.day(2_026, 10, 24, hour: 23, minute: 59, calendar: brasilia))
        let midnight = try election(
            2_026, at: MemoryFixture.day(2_026, 10, 25, hour: 0, calendar: brasilia))
        let lastMinute = try election(
            2_026, at: MemoryFixture.day(2_026, 10, 25, hour: 23, minute: 59, calendar: brasilia))
        let after = try election(
            2_026, at: MemoryFixture.day(2_026, 10, 26, hour: 0, calendar: brasilia))
        #expect(eve.rounds.last?.status == .upcoming)
        #expect(midnight.rounds.last?.status == .today)
        #expect(lastMinute.rounds.last?.status == .today)
        #expect(after.rounds.last?.status == .past)
        #expect(after.isFinished)
    }

    @Test func theDayFollowsTheCalendarTimeZone() throws {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = .gmt
        let instant = try MemoryFixture.day(2_026, 10, 26, hour: 1, calendar: utc)
        let inBrasilia = try election(2_026, at: instant)
        let inUTC = try #require(
            ElectionSchedule.elections(now: instant, calendar: utc).first { $0.year == 2_026 })
        #expect(inBrasilia.liveRound?.number == 2)
        #expect(inUTC.liveRound == nil)
        #expect(inUTC.isFinished)
    }
}
