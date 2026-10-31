import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import Foundation
import Observation

@MainActor @Observable
public final class MoneyModel {
    public enum Section: String, CaseIterable, Identifiable, Sendable {
        case mandate, quota, campaigns, revenue

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .mandate: String(appLocalized: "What a Mandate Costs")
            case .quota: String(appLocalized: "Who Spends More, and on What")
            case .campaigns: String(appLocalized: "Who Funds the Campaigns")
            case .revenue: String(appLocalized: "What the Country Collects")
            }
        }

        public var themes: [Theme] {
            switch self {
            case .quota, .mandate: [.taxes]
            case .campaigns: [.politics]
            case .revenue: [.economy, .taxes]
            }
        }

        func rank(in lens: Lens) -> Int {
            themes.map(lens.rank(of:)).min() ?? lens.themes.count
        }

        public static func order(for lens: Lens?) -> [Section] {
            guard let lens, !lens.themes.isEmpty else { return allCases }
            return allCases.enumerated()
                .sorted { lhs, rhs in
                    (lhs.element.rank(in: lens), lhs.offset) < (
                        rhs.element.rank(in: lens), rhs.offset
                    )
                }
                .map(\.element)
        }
    }

    public struct Answer: Equatable, Sendable {
        public let kicker: String
        public let value: String
        public let cents: Int
        public let unit: String
        public let sentence: String
        public let comparison: String?
        public let fact: String?
        public let caveat: String?
    }

    public private(set) var overview: MoneyOverview?
    public private(set) var mandate: MandateCost?
    public private(set) var places: MoneyPlaces?
    public private(set) var scope: String
    public private(set) var homeUF: String?
    public private(set) var lens: Lens?
    public private(set) var phase: PublicDataPhase = .idle
    @ObservationIgnored private var followsHome = true
    @ObservationIgnored private let service: (any PublicDataService)?
    @ObservationIgnored private let lensRepository: (any LensRepository)?
    @ObservationIgnored private let home: @MainActor () -> String?
    @ObservationIgnored private let requests = PublicDataRequests()

    public init(
        service: (any PublicDataService)?, lens: (any LensRepository)? = nil,
        home: @escaping @MainActor () -> String? = { HomePlace.chosenUF(in: .standard) }
    ) {
        self.service = service
        lensRepository = lens
        self.home = home
        let uf = home()
        homeUF = uf
        scope = uf ?? MoneyPlaces.country
    }

    public var isEmpty: Bool {
        guard let overview else { return true }
        return (mandate?.roles.isEmpty ?? true) && quotaCents == 0
            && (overview.campaigns?.revenueCents ?? 0) == 0 && overview.revenue == nil
            && (places?.places.isEmpty ?? true)
    }

    public var isStale: Bool { phase.error != nil && !isEmpty }

    public var sections: [Section] { Section.order(for: lens) }

    public var showsLensBadge: Bool { lens?.hasChoice == true }

    public var lensNote: String? {
        guard showsLensBadge, let first = sections.first, sections != Section.allCases else {
            return nil
        }
        return String(appLocalized: "Your lens shows \(first.title) first.")
    }

    public var states: [String] {
        let published = (places?.places ?? []).filter { !$0.isCountry }.map(\.uf)
        return (published.isEmpty ? mandateStates : published)
            .sorted {
                RaceText.scope($0).localizedStandardCompare(RaceText.scope($1)) == .orderedAscending
            }
    }

    public var scopeUF: String {
        scope != MoneyPlaces.country && states.contains(scope) ? scope : MoneyPlaces.country
    }

    public var isCountry: Bool { scopeUF == MoneyPlaces.country }

    public var scopeName: String { RaceText.scope(scopeUF) }

    public var scopeCode: String { scopeUF.uppercased(with: .app) }

    public var homeOption: String? {
        guard let homeUF, states.contains(homeUF) else { return nil }
        return homeUF
    }

    public var place: MoneyPlaces.Place? { places?.place(scopeUF) }

    public func select(scope uf: String) {
        followsHome = uf == (homeUF ?? MoneyPlaces.country)
        scope = uf
    }

    private func refreshHome() {
        let current = home()
        guard current != homeUF else { return }
        homeUF = current
        if followsHome { scope = current ?? MoneyPlaces.country }
    }

    var quotaCents: Int {
        guard let quota = overview?.quota else { return 0 }
        return quota.federalDeputiesCents + quota.senatorsCents
    }

    var minimumWageCents: Int? {
        guard let wage = mandate?.minimumWage?.monthlyCents, wage > 0 else { return nil }
        return wage
    }

    public func sourceLine(for section: Section) -> String {
        switch section {
        case .mandate:
            let all = mandate?.sources ?? []
            return MoneyText.sourceLine(MoneyText.sources(all, ids: all.map(\.id)))
        case .quota:
            let all = places?.sources ?? overview?.sources ?? []
            return MoneyText.sourceLine(MoneyText.sources(all, ids: ["camara", "senado"]))
        case .campaigns:
            return MoneyText.sourceLine(MoneyText.sources(overview?.sources ?? [], ids: ["tse"]))
        case .revenue:
            return MoneyText.sourceLine(
                MoneyText.sources(overview?.sources ?? [], ids: ["receita"]))
        }
    }

    public func load() async {
        refreshHome()
        if overview == nil { phase = .loading }
        phase = await PublicDataPhase.settle(after: phase, in: requests) {
            let lens = try? await lensRepository?.lens()
            guard let service else { throw PublicDataError.unavailable }
            let overview = try await service.money()
            return MoneyPage(
                lens: lens, overview: overview, mandate: try? await service.mandateCost(),
                places: try? await service.moneyPlaces())
        } apply: { page in
            lens = page.lens
            overview = page.overview
            mandate = page.mandate
            places = page.places
        }
    }
}

private struct MoneyPage {
    let lens: Lens?
    let overview: MoneyOverview
    let mandate: MandateCost?
    let places: MoneyPlaces?
}
