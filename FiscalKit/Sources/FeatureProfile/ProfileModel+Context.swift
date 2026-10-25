import FeatureCore
import FiscalDomain
import Foundation

extension ProfileModel {
    public enum ContextPeriod: String, Hashable, Sendable {
        case before
        case during
    }

    public struct ContextPoint: Identifiable, Hashable, Sendable {
        public let date: Date
        public let day: CalendarDay
        public let value: Double
        public let raw: Double
        public let period: ContextPeriod

        public var id: String { "\(period.rawValue)-\(day)" }
    }

    public var contextItems: [PersonContext.Item] { context?.indicators ?? [] }

    public var hasContext: Bool { !contextItems.isEmpty }

    public var selectedContext: PersonContext.Item? {
        contextItems.first { $0.id == selectedIndicatorID } ?? contextItems.first
    }

    public var mandateStartDate: Date? {
        context.map { $0.mandateStart.date(in: calendar) }
    }

    public var mandateStartLabel: String {
        String(
            appLocalized:
                "Took office · \(IndicatorFormat.month(context?.mandateStart, calendar: calendar))")
    }

    public func contextPoints(_ item: PersonContext.Item) -> [ContextPoint] {
        guard let start = context?.mandateStart else { return [] }
        let reference = PersonContext.reference(for: start)
        let base = item.kind == .index ? item.atStart : nil
        let calendar = calendar
        return item.series.flatMap { point -> [ContextPoint] in
            let value = base.map { point.value / $0 * 100 } ?? point.value
            let make = { (period: ContextPeriod) in
                ContextPoint(
                    date: point.day(in: calendar), day: point.date, value: value,
                    raw: point.value, period: period)
            }
            if point.date == reference { return [make(.before), make(.during)] }
            return [make(point.date < reference ? .before : .during)]
        }
    }

    public func contextValue(_ point: ContextPoint, item: PersonContext.Item) -> String {
        switch item.kind {
        case .price: IndicatorFormat.value(point.raw, kind: .price)
        case .index:
            String(
                appLocalized: "\(IndicatorFormat.change(point.value / 100 - 1)) since taking office"
            )
        }
    }

    public func contextSentence(_ item: PersonContext.Item) -> String {
        let subject = IndicatorFormat.subject(id: item.id, name: item.name)
        let place = IndicatorFormat.place(scope: item.scope)
        let during: String
        switch item.kind {
        case .price:
            during = String(
                appLocalized:
                    "During the term, \(subject) \(place) went from \(IndicatorFormat.value(item.atStart, kind: .price)) to \(IndicatorFormat.value(item.latest, kind: .price)) (\(IndicatorFormat.change(item.changeDuring)))."
            )
        case .index:
            during = String(
                appLocalized:
                    "During the term, \(subject) \(place) changed \(IndicatorFormat.change(item.changeDuring))."
            )
        }
        let before =
            item.changeBefore == nil
            ? String(appLocalized: "There's no data for the \(item.months) months before.")
            : String(
                appLocalized:
                    "In the \(item.months) months before, \(IndicatorFormat.change(item.changeBefore))."
            )
        return "\(during) \(before)"
    }

    public func contextAreaLine(_ item: PersonContext.Item) -> String {
        let until = IndicatorFormat.month(item.latestDate, calendar: calendar)
        return String(appLocalized: "\(item.area) · until \(until)")
    }

    public var contextFootnote: String {
        String(
            appLocalized:
                "The term starts at the month before taking office and runs to the latest month published; before is the same number of months ahead of it. It shows what changed, not why."
        )
    }

    public var contextSourceText: String? {
        SourceFootnote.text(context?.sources ?? [], calendar: calendar)
    }

    nonisolated static func context(
        for profile: Profile, service: any PublicDataService
    ) async throws -> PersonContext? {
        if let published = try await service.context(slug: profile.slug) { return published }
        guard profile.office.isMunicipal, profile.status != .electedAwaiting,
            let start = profile.mandate?.start, let catalog = try await service.indicators()
        else { return nil }
        let ids = catalog.items.map(\.id)
        let loaded = try await withThrowingTaskGroup(of: (Int, Indicator?).self) { group in
            for (offset, id) in ids.enumerated() {
                group.addTask { (offset, try await service.indicator(id: id)) }
            }
            var out: [(Int, Indicator)] = []
            for try await (offset, indicator) in group {
                if let indicator { out.append((offset, indicator)) }
            }
            return out.sorted { $0.0 < $1.0 }.map(\.1)
        }
        return PersonContext.calculate(loaded, mandateStart: start, uf: profile.uf)
    }
}

extension IndicatorPoint {
    func day(in calendar: Calendar) -> Date { date.date(in: calendar) }
}
