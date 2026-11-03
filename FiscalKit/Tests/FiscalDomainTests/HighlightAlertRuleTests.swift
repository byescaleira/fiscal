import FiscalDomain
import Foundation
import Testing

struct HighlightAlertRuleTests {
    private let rule = HighlightAlertRule.standard
    private let calendar = HighlightAlertRule.brasilia

    private func highlight(_ id: String = "a", weight: Int = 85, on date: String = "2026-11-03")
        -> Highlight
    {
        Highlight(
            id: id, kind: .action, title: "Destaque \(id)", subtitle: "", weight: weight,
            repercussion: nil, impact: 60, route: "pessoa", person: nil, proposition: nil,
            date: day(date), url: nil, signals: .none)
    }

    private func day(_ value: String) -> CalendarDay {
        CalendarDay(value) ?? CalendarDay(.distantPast, calendar: calendar)
    }

    private func moment(_ day: Int, hour: Int = 12, minute: Int = 0) -> Date {
        calendar.date(
            from: DateComponents(year: 2_026, month: 11, day: day, hour: hour, minute: minute))
            ?? .distantPast
    }

    @Test func theStandardRuleAsksForWeightEightyFiveAndOneDay() {
        #expect(rule.minWeight == 85)
        #expect(rule.maxAgeHours == 24)
    }

    @Test(arguments: [(84, false), (85, true), (100, true)])
    func theWeightMustReachTheMinimum(weight: Int, passes: Bool) {
        #expect(rule.passes(highlight(weight: weight), now: moment(3)) == passes)
    }

    @Test func aDateStillToComeDoesNotPass() {
        #expect(!rule.passes(highlight(on: "2026-11-04"), now: moment(3)))
    }

    @Test func theDayItselfAndTheNextFullDayPassAndNothingAfter() {
        let item = highlight(on: "2026-11-03")
        #expect(rule.passes(item, now: moment(3, hour: 0)))
        #expect(rule.passes(item, now: moment(4, hour: 23, minute: 59)))
        #expect(rule.passes(item, now: moment(5, hour: 0)))
        #expect(!rule.passes(item, now: moment(5, hour: 0, minute: 1)))
    }

    @Test func theDayCountsInBrasiliaAndNotInTheDeviceTimeZone() {
        let item = highlight(on: "2026-11-03")
        let lastMinuteOfTheEve = moment(2, hour: 23, minute: 59)
        #expect(!rule.passes(item, now: lastMinuteOfTheEve))
    }

    @Test func pickSkipsWhatWasAlreadyShownAndWhatDoesNotPass() {
        let items = [
            highlight("light", weight: 60), highlight("shown", weight: 90),
            highlight("next", weight: 85), highlight("last", weight: 95),
        ]
        let pick = rule.pick(from: items, shown: ["shown"], now: moment(3))
        #expect(pick?.id == "next")
    }

    @Test func pickFindsNothingWhenEveryItemWasShownOrIsTooLight() {
        let items = [highlight("light", weight: 60), highlight("shown", weight: 90)]
        #expect(rule.pick(from: items, shown: ["shown"], now: moment(3)) == nil)
    }

    @Test func aPublishedRuleReplacesTheStandardOne() {
        let lower = HighlightAlertRule(minWeight: 70, maxAgeHours: 24)
        #expect(lower.passes(highlight(weight: 70), now: moment(3)))
        #expect(!rule.passes(highlight(weight: 70), now: moment(3)))
    }

    @Test func theLedgerRemembersOnlyTheLastSixty() {
        let suite = "test.highlight-ledger.\(UUID().uuidString)"
        defer { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        let ledger = HighlightAlertLedger(suiteName: suite)
        for index in 0...HighlightAlertLedger.shownLimit { ledger.record("id-\(index)") }
        ledger.record("id-1")
        #expect(ledger.shown.count == HighlightAlertLedger.shownLimit)
        #expect(!ledger.shown.contains("id-0"))
        #expect(ledger.shown.contains("id-\(HighlightAlertLedger.shownLimit)"))
    }
}
