import Foundation

public struct IndicatorPoint: Codable, Hashable, Sendable {
    public let date: CalendarDay
    public let value: Double

    public init(date: CalendarDay, value: Double) {
        self.date = date
        self.value = value
    }
}

public enum IndicatorKind: String, Codable, Hashable, Sendable {
    case price
    case index
}

public struct Indicator: Codable, Hashable, Identifiable, Sendable {
    public static let brazil = "br"

    public struct Area: Codable, Hashable, Identifiable, Sendable {
        public let scope: String
        public let name: String
        public let series: [IndicatorPoint]

        public init(scope: String, name: String, series: [IndicatorPoint]) {
            self.scope = scope
            self.name = name
            self.series = series
        }

        public var id: String { scope }
    }

    public let id: String
    public let name: String
    public let unit: String
    public let kind: IndicatorKind
    public let scope: String
    public let areas: [Area]
    public let sources: [Source]

    public init(
        id: String, name: String, unit: String, kind: IndicatorKind, areas: [Area],
        sources: [Source]
    ) {
        self.id = id
        self.name = name
        self.unit = unit
        self.kind = kind
        scope = areas.contains { $0.scope != Self.brazil } ? "uf" : Self.brazil
        self.areas = areas
        self.sources = sources
    }

    public func area(_ scope: String) -> Area? {
        areas.first { $0.scope == scope && !$0.series.isEmpty }
    }

    public func area(closestTo uf: String) -> Area? {
        area(uf.lowercased()) ?? area(Self.brazil)
    }
}

public struct IndicatorSummary: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let unit: String
    public let kind: IndicatorKind
    public let scope: String
    public let scopes: [String]
    public let start: CalendarDay?
    public let latest: Double?
    public let latestDate: CalendarDay?
    public let change12m: Double?

    public init(_ indicator: Indicator) {
        id = indicator.id
        name = indicator.name
        unit = indicator.unit
        kind = indicator.kind
        scope = indicator.scope
        scopes = indicator.areas.map(\.scope)
        let series = indicator.area(Indicator.brazil)?.series ?? []
        start = series.first?.date
        latest = series.last?.value
        latestDate = series.last?.date
        change12m = series.last.flatMap { last in
            IndicatorMath.value(in: series, at: IndicatorMath.month(last.date, adding: -12))
                .flatMap { IndicatorMath.change(from: $0, to: last.value) }
        }
    }
}

public struct IndicatorCatalog: Codable, Hashable, Sendable {
    public let items: [IndicatorSummary]
    public let sources: [Source]

    public init(items: [IndicatorSummary], sources: [Source]) {
        self.items = items
        self.sources = sources
    }
}

public enum IndicatorMath {
    public static func month(_ day: CalendarDay, adding months: Int) -> CalendarDay {
        let total = day.year * 12 + day.month - 1 + months
        return CalendarDay(year: total / 12, month: total % 12 + 1, day: 1) ?? day
    }

    public static func months(from start: CalendarDay, to end: CalendarDay) -> Int {
        (end.year - start.year) * 12 + end.month - start.month
    }

    public static func value(in series: [IndicatorPoint], at day: CalendarDay) -> Double? {
        series.first { $0.date.year == day.year && $0.date.month == day.month }?.value
    }

    public static func change(from start: Double, to end: Double) -> Double? {
        guard start > 0 else { return nil }
        return end / start - 1
    }
}
