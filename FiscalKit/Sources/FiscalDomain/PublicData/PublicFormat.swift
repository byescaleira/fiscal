import Foundation

public enum PublicFormat {
    public static let missing = "—"

    public static func updated(_ date: Date, calendar: Calendar = FiscalCalendar.current)
        -> String
    {
        let style = Date.VerbatimFormatStyle(
            format:
                "\(day: .twoDigits)/\(month: .twoDigits), \(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits)",
            timeZone: calendar.timeZone, calendar: calendar)
        return date.formatted(style)
    }

    public static func reais(cents: Int) -> Decimal {
        Decimal(cents) / 100
    }

    public static func money(cents: Int?, locale: Locale = .app) -> String {
        guard let cents else { return missing }
        return reais(cents: cents).formatted(.currency(code: "BRL").locale(locale))
    }

    public static func compactMoney(cents: Int?, locale: Locale = .app) -> String {
        guard let cents else { return missing }
        return reais(cents: cents).formatted(
            .currency(code: "BRL").notation(.compactName).precision(.fractionLength(0...1))
                .locale(locale))
    }

    public static func number(_ value: Int?, locale: Locale = .app) -> String {
        guard let value else { return missing }
        return value.formatted(.number.locale(locale))
    }

    public static func percent(_ fraction: Double?, locale: Locale = .app) -> String {
        guard let fraction, fraction.isFinite else { return missing }
        return fraction.formatted(.percent.precision(.fractionLength(0...1)).locale(locale))
    }
}
