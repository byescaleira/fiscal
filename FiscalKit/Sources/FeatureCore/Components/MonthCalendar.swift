import FiscalDomain
import Foundation

public struct MonthCalendar: Equatable, Sendable {
    public let year: Int
    public let selection: YearMonth
    public let today: YearMonth
    public let unavailable: Set<YearMonth>
    public let unavailableTitle: String
    public let locale: Locale

    public init(
        year: Int, selection: YearMonth, today: YearMonth = YearMonth(.now),
        unavailable: Set<YearMonth> = [], unavailableTitle: String = "", locale: Locale = .app
    ) {
        self.year = year
        self.selection = selection
        self.today = today
        self.unavailable = unavailable
        self.unavailableTitle = unavailableTitle
        self.locale = locale
    }

    public var yearTitle: String { String(year) }

    public var selectionTitle: String { title(for: selection) }

    public var relativeTitle: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale
        formatter.dateTimeStyle = .named
        formatter.unitsStyle = .full
        return Self.capitalizingFirst(
            formatter.localizedString(from: DateComponents(month: selection.months(since: today))),
            locale: locale)
    }

    public var canJumpToToday: Bool {
        (year != today.year || selection != today) && !unavailable.contains(today)
    }

    public var choices: [MonthChoice] {
        let symbols = Self.symbols(locale: locale)
        return (1...12).compactMap { number in
            guard let month = YearMonth(year: year, month: number) else { return nil }
            return MonthChoice(
                month: month, title: symbols[number - 1], fullTitle: title(for: month),
                isSelected: month == selection, time: time(of: month),
                isAvailable: !unavailable.contains(month), detail: detail(for: month))
        }
    }

    public func moving(by years: Int) -> MonthCalendar {
        MonthCalendar(
            year: year + years, selection: selection, today: today, unavailable: unavailable,
            unavailableTitle: unavailableTitle, locale: locale)
    }

    public static func columns(isAccessibilitySize: Bool, isWide: Bool) -> Int {
        isAccessibilitySize ? 3 : isWide ? 6 : 4
    }

    static func symbols(locale: Locale) -> [String] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        return calendar.shortStandaloneMonthSymbols.map {
            capitalizingFirst($0.replacingOccurrences(of: ".", with: ""), locale: locale)
        }
    }

    private static func capitalizingFirst(_ text: String, locale: Locale) -> String {
        text.prefix(1).uppercased(with: locale) + text.dropFirst()
    }

    private func title(for month: YearMonth) -> String {
        month.startDate.formatted(.dateTime.month(.wide).year().locale(locale))
    }

    private func time(of month: YearMonth) -> MonthChoice.Time {
        month < today ? .past : month == today ? .current : .future
    }

    private func detail(for month: YearMonth) -> String {
        [
            month == today ? String(appLocalized: "Current month") : nil,
            unavailable.contains(month) && !unavailableTitle.isEmpty ? unavailableTitle : nil,
        ]
        .compactMap { $0 }
        .formatted(.list(type: .and).locale(locale))
    }
}
