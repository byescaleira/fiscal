import Foundation

public struct PersonContext: Codable, Hashable, Sendable {
    public struct Item: Codable, Hashable, Identifiable, Sendable {
        public let id: String
        public let name: String
        public let unit: String
        public let kind: IndicatorKind
        public let scope: String
        public let area: String
        public let atStart: Double?
        public let atStartDate: CalendarDay?
        public let latest: Double?
        public let latestDate: CalendarDay?
        public let months: Int
        public let changeDuring: Double?
        public let beforeDate: CalendarDay?
        public let changeBefore: Double?
        public let series: [IndicatorPoint]

        public init(
            indicator: Indicator, area: Indicator.Area, reference: CalendarDay
        ) {
            id = indicator.id
            name = indicator.name
            unit = indicator.unit
            kind = indicator.kind
            scope = area.scope
            self.area = area.name
            let last = area.series.last
            latest = last?.value
            latestDate = last?.date
            let count = last.map { IndicatorMath.months(from: reference, to: $0.date) } ?? 0
            months = count
            let from = IndicatorMath.month(reference, adding: -count)
            let start = IndicatorMath.value(in: area.series, at: reference)
            let before = IndicatorMath.value(in: area.series, at: from)
            atStart = start
            atStartDate = start == nil ? nil : reference
            changeDuring = Self.change(from: start, to: last?.value)
            beforeDate = start != nil && before != nil ? from : nil
            changeBefore = Self.change(from: before, to: start)
            series = area.series.filter { $0.date >= from }
        }

        private static func change(from start: Double?, to end: Double?) -> Double? {
            guard let start, let end else { return nil }
            return IndicatorMath.change(from: start, to: end)
        }
    }

    public let mandateStart: CalendarDay
    public let scope: String
    public let indicators: [Item]
    public let sources: [Source]

    public init(
        mandateStart: CalendarDay, scope: String, indicators: [Item], sources: [Source]
    ) {
        self.mandateStart = mandateStart
        self.scope = scope
        self.indicators = indicators
        self.sources = sources
    }

    public static func reference(for mandateStart: CalendarDay) -> CalendarDay {
        IndicatorMath.month(mandateStart, adding: -1)
    }

    public static func calculate(
        _ indicators: [Indicator], mandateStart: CalendarDay, uf: String
    ) -> PersonContext? {
        let scope = uf.isEmpty ? Indicator.brazil : uf.lowercased()
        let reference = reference(for: mandateStart)
        let items = indicators.compactMap { indicator -> Item? in
            guard let area = indicator.area(closestTo: scope), let last = area.series.last,
                last.date > reference
            else { return nil }
            return Item(indicator: indicator, area: area, reference: reference)
        }
        guard !items.isEmpty else { return nil }
        var sources: [Source] = []
        for source in indicators.flatMap(\.sources)
        where !sources.contains(where: { $0.id == source.id }) {
            sources.append(source)
        }
        return PersonContext(
            mandateStart: mandateStart, scope: scope, indicators: items, sources: sources)
    }
}
