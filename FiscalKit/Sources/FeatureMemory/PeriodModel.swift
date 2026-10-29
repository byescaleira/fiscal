import FeatureCore
import FiscalDomain
import Foundation
import Observation

@MainActor @Observable
public final class PeriodModel {
    public let id: String
    public private(set) var phase: PublicDataPhase = .idle
    public private(set) var timeline: PoliticalTimeline?
    @ObservationIgnored private let service: (any PublicDataService)?
    @ObservationIgnored private let requests = PublicDataRequests()

    public init(id: String, service: (any PublicDataService)?) {
        self.id = id
        self.service = service
    }

    var period: PoliticalPeriod? { timeline?.periods.first { $0.id == id } }

    var previous: PoliticalPeriod? { neighbor(-1) }

    var next: PoliticalPeriod? { neighbor(1) }

    var years: String {
        guard let period else { return PublicFormat.missing }
        return MemoryText.years(start: period.startDay, end: period.endDay)
    }

    var presidentsLine: String {
        let count = period?.presidents.count ?? 0
        return String(appLocalized: "\(count) heads of government")
    }

    public func load() async {
        guard let service else {
            phase = .failed(.unavailable)
            return
        }
        if timeline == nil { phase = .loading }
        phase = await PublicDataPhase.settle(after: phase, in: requests) {
            try await service.politicalTimeline()
        } apply: { loaded in
            timeline = loaded
        }
    }

    func term(_ president: PeriodPresident) -> String {
        let start = CalendarDay(president.start).map(SourceFootnote.day) ?? president.start
        guard let end = president.end else { return String(appLocalized: "Since \(start)") }
        let finish = CalendarDay(end).map(SourceFootnote.day) ?? end
        return "\(start) – \(finish)"
    }

    func value(_ value: Double, unit: String) -> String {
        let number = value.formatted(.number.precision(.fractionLength(0...2)).locale(.app))
        return unit.hasPrefix("%") ? "\(number)%" : "\(number) \(unit)"
    }

    func summary(_ indicator: PeriodIndicator) -> String {
        var parts: [String] = []
        if let average = indicator.average {
            parts.append(String(appLocalized: "Average \(value(average, unit: indicator.unit))"))
        }
        if let low = indicator.min {
            parts.append(
                String(
                    appLocalized:
                        "Lowest \(value(low.value, unit: indicator.unit)) in \(String(low.year))"))
        }
        if let high = indicator.max {
            parts.append(
                String(
                    appLocalized:
                        "Highest \(value(high.value, unit: indicator.unit)) in \(String(high.year))"
                ))
        }
        return parts.joined(separator: " · ")
    }

    func footnote(_ indicator: PeriodIndicator) -> String {
        var parts = [indicator.note, String(appLocalized: "Source: \(indicator.source).")]
        if usesLogScale(indicator) {
            parts.append(
                String(appLocalized: "Logarithmic scale, so small and very large values fit."))
        }
        return parts.joined(separator: " ")
    }

    func usesLogScale(_ indicator: PeriodIndicator) -> Bool {
        (indicator.max?.value ?? 0) > 100 && (indicator.min?.value ?? 0) > 0
    }

    private func neighbor(_ step: Int) -> PoliticalPeriod? {
        guard let periods = timeline?.periods,
            let index = periods.firstIndex(where: { $0.id == id })
        else { return nil }
        let target = index + step
        return periods.indices.contains(target) ? periods[target] : nil
    }
}
