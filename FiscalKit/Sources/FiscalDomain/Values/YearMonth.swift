import Foundation

public struct YearMonth: Hashable, Comparable, Sendable {
    public let year: Int
    public let month: Int

    public init?(year: Int, month: Int) {
        guard year > 0, (1...12).contains(month) else { return nil }
        self.year = year
        self.month = month
    }

    public init?(rawValue: Int) {
        self.init(year: rawValue / 100, month: rawValue % 100)
    }

    public init(monthIndex: Int) {
        year = monthIndex / 12
        month = monthIndex % 12 + 1
    }

    public init(_ date: Date) {
        let components = FiscalCalendar.current.dateComponents([.year, .month], from: date)
        year = components.year ?? 1
        month = components.month ?? 1
    }

    public var rawValue: Int { year * 100 + month }

    public var monthIndex: Int { year * 12 + month - 1 }

    public var startDate: Date {
        FiscalCalendar.current.date(from: DateComponents(year: year, month: month, day: 1))
            ?? .distantPast
    }

    public var dayCount: Int {
        FiscalCalendar.current.range(of: .day, in: .month, for: startDate)?.count ?? 31
    }

    public func adding(months: Int) -> YearMonth {
        YearMonth(monthIndex: monthIndex + months)
    }

    public func months(since start: YearMonth) -> Int {
        monthIndex - start.monthIndex
    }

    public static func < (lhs: YearMonth, rhs: YearMonth) -> Bool {
        lhs.monthIndex < rhs.monthIndex
    }
}
