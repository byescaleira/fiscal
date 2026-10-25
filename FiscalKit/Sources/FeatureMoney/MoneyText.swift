import FiscalDomain
import Foundation

public struct AmountBar: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let kind: MoneyKind
    public let cents: Int
    public let value: String
    public let detail: String?

    public var reais: Double { Double(cents) / 100 }
}

public struct MonthBar: Identifiable, Equatable, Sendable {
    public let month: Int
    public let label: String
    public let name: String
    public let cents: Int?
    public let value: String

    public var id: Int { month }
    public var reais: Double { Double(cents ?? 0) / 100 }
}

public enum MoneyText {
    public static func sourceLine(
        _ sources: [Source], calendar: Calendar = FiscalCalendar.current
    ) -> String {
        guard !sources.isEmpty else {
            return String(appLocalized: "Source: \(PublicFormat.missing)")
        }
        let names = sources.map(\.name).formatted(.list(type: .and).locale(.app))
        guard let updated = sources.compactMap(\.updatedAt).max() else {
            return String(appLocalized: "Source: \(names)")
        }
        let when = updatedText(updated, calendar: calendar)
        return String(appLocalized: "Source: \(names) · updated \(when)")
    }

    public static func updatedText(_ date: Date, calendar: Calendar = FiscalCalendar.current)
        -> String
    {
        PublicFormat.updated(date, calendar: calendar)
    }

    public static func sources(_ all: [Source], ids: [String]) -> [Source] {
        let matching = all.filter { ids.contains($0.id) }
        return matching.isEmpty ? all : matching
    }

    public static func monthNames(calendar: Calendar = FiscalCalendar.current) -> [String] {
        var calendar = calendar
        calendar.locale = .app
        return calendar.standaloneMonthSymbols.map { $0.capitalized(with: .app) }
    }

    public static func monthLabels(calendar: Calendar = FiscalCalendar.current) -> [String] {
        var calendar = calendar
        calendar.locale = .app
        return calendar.shortStandaloneMonthSymbols.map {
            $0.replacingOccurrences(of: ".", with: "").capitalized(with: .app)
        }
    }

    public static func cnpj(_ document: String?) -> String? {
        guard let document else { return nil }
        let digits = Array(document.filter(\.isNumber))
        guard digits.count == 14 else { return document }
        let text = String(digits)
        let parts = [0..<2, 2..<5, 5..<8, 8..<12, 12..<14].map { range in
            String(text.dropFirst(range.lowerBound).prefix(range.count))
        }
        return "\(parts[0]).\(parts[1]).\(parts[2])/\(parts[3])-\(parts[4])"
    }

    public static func bars<Item>(
        _ items: [Item], id: (Item) -> String, title: (Item) -> String, cents: (Item) -> Int,
        kind: (Item) -> MoneyKind, detail: (Item) -> String? = { _ in nil }
    ) -> [AmountBar] {
        items.enumerated()
            .sorted { lhs, rhs in
                (-cents(lhs.element), lhs.offset) < (-cents(rhs.element), rhs.offset)
            }
            .map { entry in
                let item = entry.element
                return AmountBar(
                    id: id(item), title: title(item), kind: kind(item), cents: cents(item),
                    value: PublicFormat.compactMoney(cents: cents(item)), detail: detail(item))
            }
    }
}
