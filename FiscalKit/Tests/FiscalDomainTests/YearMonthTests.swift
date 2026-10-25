import FiscalDomain
import Testing

struct YearMonthTests {
    @Test func rejectsInvalidMonths() {
        #expect(YearMonth(year: 2026, month: 13) == nil)
        #expect(YearMonth(year: 2026, month: 0) == nil)
    }

    @Test func addsMonthsAcrossYears() throws {
        let november = try #require(YearMonth(year: 2026, month: 11))
        let february = try #require(YearMonth(year: 2027, month: 2))
        #expect(november.adding(months: 3) == february)
        #expect(february.months(since: november) == 3)
    }

    @Test func roundTripsTheRawValue() throws {
        let month = try #require(YearMonth(year: 2026, month: 7))
        #expect(YearMonth(rawValue: month.rawValue) == month)
    }
}
