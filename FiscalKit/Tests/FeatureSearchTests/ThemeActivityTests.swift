import FiscalData
import FiscalDomain
import Foundation
import Testing

@testable import FeatureSearch

struct ThemeActivityTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo") ?? .gmt
        calendar.locale = Locale(identifier: "pt_BR")
        return calendar
    }

    private func vote(
        _ id: String, day: Int, month: Int = 10, themes: [Theme], approved: Bool? = true
    ) -> VoteSummary {
        VoteSummary(
            id: id, house: .camara,
            date: CalendarDay(year: 2026, month: month, day: day) ?? CalendarDay(Date.now),
            time: nil, proposition: id, kind: nil, summary: id, plainSummary: nil,
            themes: themes, result: nil, approved: approved, nominal: true,
            tally: VoteSummary.Tally(yes: 1, no: 0, others: 0))
    }

    @Test func countsVotesPerTopicAndOrdersByCountThenByTheTopicOrder() {
        let activity = ThemeActivity(
            votes: [
                vote("a", day: 20, themes: [.health, .economy]),
                vote("b", day: 21, themes: [.economy], approved: false),
                vote("c", day: 22, themes: [.education], approved: nil),
            ],
            themes: [.health, .education, .economy, .security], calendar: calendar)
        #expect(activity.total == 3)
        #expect(activity.slices.map(\.theme) == [.economy, .health, .education, .security])
        #expect(activity.slices.map(\.count) == [2, 1, 1, 0])
        #expect(activity.slices.map(\.slot) == [2, 0, 1, 3])
        let economy = activity.slices[0]
        #expect(economy.approved == 1)
        #expect(economy.rejected == 1)
        #expect(activity.maxCount == 2)
        #expect(activity.leader?.theme == .economy)
    }

    @Test func colorSlotsFollowTheTopicNotItsRank() {
        let themes: [Theme] = [.health, .education]
        let first = ThemeActivity(
            votes: [vote("a", day: 20, themes: [.education])], themes: themes,
            calendar: calendar)
        let second = ThemeActivity(
            votes: [vote("a", day: 20, themes: [.health])], themes: themes, calendar: calendar)
        #expect(first.slot(of: .education) == 1)
        #expect(second.slot(of: .education) == 1)
        #expect(first.slices.first?.theme == .education)
        #expect(second.slices.first?.theme == .health)
    }

    @Test func hasNoLeaderWhenTopicsTieOrNothingMatches() {
        let tied = ThemeActivity(
            votes: [
                vote("a", day: 20, themes: [.health]), vote("b", day: 20, themes: [.education]),
            ],
            themes: [.health, .education], calendar: calendar)
        #expect(tied.leader == nil)
        #expect(tied.touchesThemes)
        let untouched = ThemeActivity(
            votes: [vote("a", day: 20, themes: [.culture])], themes: [.health],
            calendar: calendar)
        #expect(untouched.hasVotes)
        #expect(!untouched.touchesThemes)
        #expect(untouched.leader == nil)
        #expect(untouched.periods.isEmpty)
    }

    @Test func groupsShortSpansByDayAndFillsTheGaps() throws {
        let activity = ThemeActivity(
            votes: [
                vote("a", day: 20, themes: [.health]),
                vote("b", day: 20, themes: [.economy]),
                vote("c", day: 23, themes: [.health, .economy]),
                vote("d", day: 23, themes: [.culture]),
            ],
            themes: [.health, .economy], calendar: calendar)
        #expect(activity.grain == .day)
        #expect(activity.periods.map(\.count) == [2, 0, 0, 1])
        #expect(activity.periods.first?.themes == [.health, .economy])
        #expect(activity.periods.last?.themes == [.health, .economy])
        #expect(activity.average == 0.75)
        let monday = try #require(CalendarDay(year: 2026, month: 10, day: 23)).date(in: calendar)
        let noon = monday.addingTimeInterval(12 * 3_600)
        #expect(activity.period(at: noon)?.count == 1)
    }

    @Test func groupsLongSpansByWeek() {
        let activity = ThemeActivity(
            votes: [
                vote("a", day: 1, themes: [.health]),
                vote("b", day: 2, themes: [.health]),
                vote("c", day: 20, themes: [.health]),
            ],
            themes: [.health], calendar: calendar)
        #expect(activity.grain == .week)
        #expect(activity.periods.map(\.count).reduce(0, +) == 3)
        #expect(activity.periods.count >= 3)
        #expect(activity.periods.first?.count == 2)
    }

    @Test func thinsTheAxisLabelsToAFew() {
        let votes = (1...12).map { vote("v\($0)", day: $0, themes: [.health]) }
        let activity = ThemeActivity(votes: votes, themes: [.health], calendar: calendar)
        let shown = activity.periods.filter { activity.showsLabel(at: $0.start) }
        #expect(activity.grain == .day)
        #expect(shown.count <= ThemeActivity.axisLabelLimit)
        #expect(shown.first == activity.periods.first)
    }

    @Test func longSeriesScrollAndStartAtTheLatestPeriods() {
        let votes = (1...30).map { day in
            vote("v\(day)", day: day, month: day.isMultiple(of: 2) ? 7 : 9, themes: [.health])
        }
        let activity = ThemeActivity(votes: votes, themes: [.health], calendar: calendar)
        #expect(activity.grain == .week)
        #expect(activity.isScrollable)
        #expect(activity.visibleLength == 12 * 604_800)
        #expect(activity.scrollStart == activity.periods[activity.periods.count - 12].start)
        let short = ThemeActivity(
            votes: [vote("a", day: 20, themes: [.health]), vote("b", day: 22, themes: [.health])],
            themes: [.health], calendar: calendar)
        #expect(!short.isScrollable)
        #expect(short.scrollStart == short.periods.first?.start)
        #expect(short.visibleLength == 3 * 86_400)
    }

    @Test func placeholderHasOneDecreasingBarPerTopic() {
        let activity = ThemeActivity.placeholder(themes: [.health, .education, .economy])
        #expect(activity.slices.map(\.count) == [3, 2, 1])
    }
}
