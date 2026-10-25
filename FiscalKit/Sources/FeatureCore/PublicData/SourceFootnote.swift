import FiscalDomain
import Foundation

public enum SourceFootnote {
    public static func text(
        _ sources: [Source], calendar: Calendar = FiscalCalendar.current
    ) -> String? {
        var names: [String] = []
        for source in sources where !names.contains(source.name) { names.append(source.name) }
        guard !names.isEmpty else { return nil }
        let list = names.joined(separator: ", ")
        guard let updated = sources.compactMap(\.updatedAt).max() else {
            return String(appLocalized: "Source: \(list)")
        }
        return String(
            appLocalized: "Source: \(list) · updated \(stamp(updated, calendar: calendar))")
    }

    public static func stamp(_ date: Date, calendar: Calendar = FiscalCalendar.current) -> String {
        let parts = calendar.dateComponents([.day, .month, .hour, .minute], from: date)
        return String(
            format: "%02d/%02d, %02d:%02d", parts.day ?? 0, parts.month ?? 0, parts.hour ?? 0,
            parts.minute ?? 0)
    }

    public static func day(_ day: CalendarDay) -> String {
        String(format: "%02d/%02d/%04d", day.day, day.month, day.year)
    }
}
