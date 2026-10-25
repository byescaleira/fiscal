import FeatureCore
import FiscalDomain
import Foundation
import Observation

@MainActor @Observable
public final class MoneyModel {
    public struct Line: Identifiable, Equatable {
        public let id: String
        public let title: String
        public let detail: String?
        public let value: String
    }

    public private(set) var overview: MoneyOverview?
    public private(set) var phase: PublicDataPhase = .idle
    @ObservationIgnored private let service: (any PublicDataService)?

    public init(service: (any PublicDataService)?) {
        self.service = service
    }

    public var isEmpty: Bool {
        guard let overview else { return true }
        return overview.salaries.isEmpty && overview.quota.federalDeputiesCents == 0
            && overview.quota.senatorsCents == 0 && (overview.campaigns?.revenueCents ?? 0) == 0
    }

    public var quota: [Line] {
        guard let overview else { return [] }
        let year = String(appLocalized: "Total in \(String(overview.year))")
        return [
            Line(
                id: "deputies", title: String(appLocalized: "All federal deputies"), detail: year,
                value: PublicFormat.compactMoney(cents: overview.quota.federalDeputiesCents)),
            Line(
                id: "senators", title: String(appLocalized: "All senators"), detail: year,
                value: PublicFormat.compactMoney(cents: overview.quota.senatorsCents)),
        ]
    }

    public var salaries: [Line] {
        (overview?.salaries ?? []).map { salary in
            Line(
                id: salary.office.rawValue, title: salary.office.title, detail: salary.law,
                value: PublicFormat.money(cents: salary.monthlyCents))
        }
    }

    public func load() async {
        if overview == nil { phase = .loading }
        phase = await PublicDataPhase.settle(after: phase) {
            guard let service else { throw PublicDataError.unavailable }
            overview = try await service.money()
        }
    }
}
