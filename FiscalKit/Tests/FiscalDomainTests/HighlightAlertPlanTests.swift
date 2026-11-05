import FiscalDomain
import Foundation
import Testing

struct HighlightAlertPlanTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: -4 * 3_600) ?? .gmt
        return calendar
    }()
    private let schedule = HighlightAlertSchedule.standard
    private let rule = HighlightAlertRule.standard

    private func highlight(_ id: String, weight: Int, on date: String = "2026-11-03") -> Highlight {
        Highlight(
            id: id, kind: .action, title: "Destaque \(id)", subtitle: "", weight: weight,
            repercussion: nil, impact: 60, route: "pessoa", person: nil, proposition: nil,
            date: CalendarDay(date) ?? CalendarDay(.distantPast), url: nil, signals: .none)
    }

    private func moment(_ day: Int, _ hour: Int, _ minute: Int = 0, _ second: Int = 0) -> Date {
        calendar.date(
            from: DateComponents(
                year: 2_026, month: 11, day: day, hour: hour, minute: minute, second: second))
            ?? .distantPast
    }

    private func plan(
        _ items: [Highlight], shown: Set<String> = [], excluding: Set<String> = [],
        activity: Bool = true, notification: Bool = true, now: Date
    ) -> HighlightAlertPlan {
        HighlightAlertPlanner.plan(
            items: items, shown: shown, excluding: excluding, rule: rule, wantsActivity: activity,
            wantsNotification: notification,
            slots: schedule.slots(offset: 0, now: now, calendar: calendar))
    }

    @Test func theHoursAreEightAndNineteenWithUpToTenMinutesOfOffset() {
        #expect(schedule.activityHour == 8)
        #expect(schedule.notificationHour == 19)
        #expect(HighlightAlertSchedule.offsetRange == 0...600)
    }

    @Test func nightOpeningSchedulesTheNextMorning() {
        let result = plan(
            [highlight("h1", weight: 92), highlight("h2", weight: 90)], now: moment(3, 22))
        #expect(result.activity == PlannedAlert(highlightId: "h1", fireDate: moment(4, 8)))
        #expect(result.notification == PlannedAlert(highlightId: "h2", fireDate: moment(4, 19)))
    }

    @Test func theNextSlotNeedsSixtySecondsOfLead() {
        #expect(
            schedule.next(hour: 8, offset: 0, now: moment(3, 7), calendar: calendar) == moment(3, 8)
        )
        #expect(
            schedule.next(hour: 8, offset: 0, now: moment(3, 7, 59, 30), calendar: calendar)
                == moment(4, 8))
    }

    @Test func theOffsetMovesTheSlotAndCountsForTheLead() {
        #expect(
            schedule.next(hour: 8, offset: 600, now: moment(3, 8, 5), calendar: calendar)
                == moment(3, 8, 10))
    }

    @Test func theRuleCountsAtTheHourOfTheAlert() {
        let old = highlight("h4", weight: 92, on: "2026-11-02")
        let result = plan([old], now: moment(3, 23))
        #expect(result.activity == nil)
        #expect(result.notification == nil)
    }

    @Test func lowWeightAndEmptyListPlanNothing() {
        #expect(plan([highlight("h5", weight: 69)], now: moment(3, 22)) == HighlightAlertPlan())
        #expect(plan([], now: moment(3, 22)) == HighlightAlertPlan())
    }

    @Test func aSingleHighlightGoesOnlyToTheActivity() {
        let result = plan([highlight("h1", weight: 92)], now: moment(3, 22))
        #expect(result.activity?.highlightId == "h1")
        #expect(result.notification == nil)
    }

    @Test func withoutTheActivityTheNotificationTakesTheFirst() {
        let items = [highlight("h1", weight: 92), highlight("h2", weight: 90)]
        let result = plan(items, activity: false, now: moment(3, 22))
        #expect(result.activity == nil)
        #expect(result.notification?.highlightId == "h1")
    }

    @Test func whatAlreadyAppearedIsNotChosenAgain() {
        let items = [highlight("h1", weight: 92), highlight("h2", weight: 90)]
        let result = plan(items, shown: ["h1"], notification: false, now: moment(3, 22))
        #expect(result.activity?.highlightId == "h2")
    }

    @Test func thePendingActivityIsNotRepeatedInTheBackground() {
        let items = [highlight("h1", weight: 92), highlight("h2", weight: 90)]
        let result = plan(items, excluding: ["h1"], activity: false, now: moment(3, 22))
        #expect(result.notification?.highlightId == "h2")
    }

    @Test func theSameInputAlwaysGivesTheSameChoice() {
        let items = [highlight("h1", weight: 92), highlight("h2", weight: 90)]
        let first = plan(items, now: moment(3, 22))
        let second = plan(items, now: moment(3, 22))
        #expect(first == second)
    }

    private func ledger() -> HighlightAlertLedger {
        let name = "highlight-plan-\(UUID().uuidString)"
        UserDefaults(suiteName: name)?.removePersistentDomain(forName: name)
        return HighlightAlertLedger(suiteName: name)
    }

    @Test func theNotificationStartsOffAndThePlanStartsEmpty() {
        let ledger = ledger()
        #expect(!ledger.isNotificationEnabled)
        #expect(ledger.isEnabled)
        #expect(ledger.plan == HighlightAlertPlan())
    }

    @Test func aPassedAlertEntersShownOnTheNextOpening() {
        let ledger = ledger()
        ledger.save(
            plan: HighlightAlertPlan(
                activity: PlannedAlert(highlightId: "h1", fireDate: moment(3, 8)),
                notification: PlannedAlert(highlightId: "h2", fireDate: moment(3, 19))))
        #expect(ledger.settle(now: moment(3, 9)) == ["h1"])
        #expect(ledger.shown == ["h1"])
        #expect(ledger.plan.activity == nil)
        #expect(ledger.plan.notification?.highlightId == "h2")
    }

    @Test func theOffsetIsDrawnOnceAndKept() {
        let ledger = ledger()
        #expect(ledger.deviceOffset(draw: { 42 }) == 42)
        #expect(ledger.deviceOffset(draw: { 7 }) == 42)
    }

    @Test func theLegacyTokenAndAttestKeyAreErased() throws {
        let name = "highlight-plan-\(UUID().uuidString)"
        let standardName = "highlight-standard-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)
        let standard = try #require(UserDefaults(suiteName: standardName))
        defer {
            defaults?.removePersistentDomain(forName: name)
            standard.removePersistentDomain(forName: standardName)
        }
        defaults?.set("token-1", forKey: "fiscal.highlightAlerts.token")
        standard.set("key-1", forKey: "AppAttestKeyID")
        HighlightAlertLedger(suiteName: name).clearLegacy(standard)
        #expect(defaults?.string(forKey: "fiscal.highlightAlerts.token") == nil)
        #expect(standard.string(forKey: "AppAttestKeyID") == nil)
    }
}
