import FiscalDomain
import Foundation
import Testing

@testable import FeatureCore

struct MonthCalendarTests {
    @Test func listsTwelveMonthsAndMarksTime() throws {
        let today = try #require(YearMonth(year: 2026, month: 5))
        let calendar = MonthCalendar(
            year: 2026, selection: today, today: today, locale: Locale(identifier: "en_US"))
        let choices = calendar.choices
        #expect(choices.count == 12)
        #expect(choices[3].time == .past)
        #expect(choices[4].time == .current)
        #expect(choices[4].isSelected)
        #expect(choices[5].time == .future)
        #expect(!calendar.canJumpToToday)
        #expect(calendar.moving(by: 1).canJumpToToday)
    }

    @Test func adaptsColumns() {
        #expect(MonthCalendar.columns(isAccessibilitySize: true, isWide: true) == 3)
        #expect(MonthCalendar.columns(isAccessibilitySize: false, isWide: true) == 6)
        #expect(MonthCalendar.columns(isAccessibilitySize: false, isWide: false) == 4)
    }
}
