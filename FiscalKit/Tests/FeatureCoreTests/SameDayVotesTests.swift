import FiscalDomain
import Foundation
import Testing

@testable import FeatureCore

struct SameDayVotesTests {
    private let today = CalendarDay(year: 2_026, month: 10, day: 26)
    private let earlier = CalendarDay(year: 2_026, month: 10, day: 21)

    private func mark(on date: CalendarDay?, count: Int?) throws -> String? {
        let vote = VoteSummary(
            id: "camara-1", house: .camara, date: try #require(date), time: nil,
            proposition: "PL 1/2026", kind: nil, summary: "Texto.", plainSummary: nil,
            themes: [], result: nil, approved: nil, nominal: false,
            tally: VoteSummary.Tally(yes: nil, no: nil, others: nil), relatedCount: count)
        return SameDayVotes.mark(vote, today: try #require(today))
    }

    @Test func noOtherVotesShowsNoMark() throws {
        #expect(try mark(on: today, count: nil) == nil)
        #expect(try mark(on: today, count: 0) == nil)
        #expect(try mark(on: earlier, count: 0) == nil)
    }

    @Test(arguments: [1, 4])
    func saysTodayForAVoteOfToday(count: Int) throws {
        let text = try mark(on: today, count: count)
        #expect(text == String(appLocalized: "+\(count) votes on this bill today"))
        #expect(text?.contains("+\(count)") == true)
    }

    @Test(arguments: [1, 4])
    func saysThatDayForAnEarlierVote(count: Int) throws {
        let text = try mark(on: earlier, count: count)
        let todayText = try mark(on: today, count: count)
        #expect(text == String(appLocalized: "+\(count) votes on this bill that day"))
        #expect(text?.contains("+\(count)") == true)
        #expect(text != todayText)
    }

    @Test func oneAndManyReadDifferently() throws {
        let one = try mark(on: today, count: 1)
        let many = try mark(on: today, count: 2)
        #expect(one != nil)
        #expect(many != nil)
        #expect(one != many)
    }
}
