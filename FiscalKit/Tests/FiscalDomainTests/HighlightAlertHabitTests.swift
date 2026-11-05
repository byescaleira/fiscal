import FiscalDomain
import Foundation
import Testing

struct HighlightAlertHabitTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: -4 * 3_600) ?? .gmt
        return calendar
    }()

    private func moment(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(
            from: DateComponents(year: 2_026, month: 11, day: day, hour: hour, minute: minute))
            ?? .distantPast
    }

    private func schedule(_ openings: [Date], now: Date) -> HighlightAlertSchedule {
        HighlightAlertHabit(openings: openings).schedule(now: now, calendar: calendar)
    }

    @Test func theUsualHourTakesTheActivityAndNineteenStaysForTheNotification() {
        let openings = [
            moment(10, 12, 10), moment(11, 12, 40), moment(12, 13, 5), moment(13, 12, 20),
            moment(14, 12, 15),
        ]
        let hours = schedule(openings, now: moment(15, 14))
        #expect(hours == HighlightAlertSchedule(activityHour: 12, notificationHour: 19))
        let slots = hours.slots(offset: 0, now: moment(15, 14), calendar: calendar)
        #expect(slots.activity == moment(16, 12))
        #expect(slots.notification == moment(15, 19))
    }

    @Test func twoUsualHoursFarApartTakeOneAlertEach() {
        let openings =
            [10, 11, 12].flatMap { [moment($0, 21), moment($0, 21, 40)] }
            + (10...13).map { moment($0, 7) }
        let hours = schedule(openings, now: moment(15, 15))
        #expect(hours == HighlightAlertSchedule(activityHour: 21, notificationHour: 7))
        let slots = hours.slots(offset: 0, now: moment(15, 15), calendar: calendar)
        #expect(slots.activity == moment(15, 21))
        #expect(slots.notification == moment(16, 7))
    }

    @Test func withoutEnoughHistoryTheStandardHoursStay() {
        let few = (10...13).map { moment($0, 12) }
        let twoDays = [10, 10, 10, 11, 11, 11].enumerated().map { moment($1, 9 + $0) }
        #expect(schedule(few, now: moment(15, 14)) == .standard)
        #expect(schedule(twoDays, now: moment(15, 14)) == .standard)
    }

    @Test func nightOpeningsNeverCount() {
        let openings = (10...14).flatMap { [moment($0, 23), moment($0, 3)] }
        #expect(schedule(openings, now: moment(15, 14)) == .standard)
    }

    @Test func recentOpeningsWeighMoreAndOldOnesLeave() {
        let old = (0..<10).map { moment(1, 9, $0 * 3) } + (2...4).map { moment($0, 9) }
        let recent = [18, 19, 20, 20, 19].map { moment($0, 18) }
        #expect(schedule(old + recent, now: moment(21, 6)).activityHour == 18)
        #expect(schedule(old, now: moment(30, 6)) == .standard)
    }

    @Test func openingsCloseTogetherCountOnceAndOnlySixtyStay() {
        var habit = HighlightAlertHabit()
        for minute in 0..<8 {
            habit = habit.recording(moment(10, 12, minute))
        }
        #expect(habit.openings == [moment(10, 12)])
        var many = HighlightAlertHabit()
        for step in 1...80 {
            many = many.recording(moment(1, 7).addingTimeInterval(TimeInterval(step) * 3_600))
        }
        #expect(many.openings.count == HighlightAlertHabit.limit)
    }

    @Test func theLedgerKeepsAndClearsTheHabit() {
        let name = "highlight-habit-\(UUID().uuidString)"
        defer { UserDefaults(suiteName: name)?.removePersistentDomain(forName: name) }
        let ledger = HighlightAlertLedger(suiteName: name)
        ledger.recordOpening(moment(10, 12))
        ledger.recordOpening(moment(10, 12, 10))
        ledger.recordOpening(moment(11, 12))
        #expect(ledger.habit.openings == [moment(10, 12), moment(11, 12)])
        ledger.clearHabit()
        #expect(ledger.habit.openings.isEmpty)
    }
}
