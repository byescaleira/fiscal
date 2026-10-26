import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import Foundation
import Observation

@MainActor @Observable
public final class MoneyModel {
    public enum Section: String, CaseIterable, Identifiable, Sendable {
        case quota, salaries, campaigns, revenue

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .quota: String(appLocalized: "Office allowance")
            case .salaries: String(appLocalized: "Salaries")
            case .campaigns: String(appLocalized: "Campaigns")
            case .revenue: String(appLocalized: "Federal revenue")
            }
        }

        public var themes: [Theme] {
            switch self {
            case .quota, .salaries: [.taxes]
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

    public struct Salary: Identifiable, Equatable, Sendable {
        public let id: String
        public let title: String
        public let law: String
        public let symbol: String
        public let cents: Int
        public let value: String

        public var reais: Double { Double(cents) / 100 }
    }

    public struct Hero: Equatable, Sendable {
        public let chip: String
        public let value: String
        public let cents: Int
        public let caption: String
        public let chamber: String
        public let senate: String
        public let chamberShare: Double
    }

    public private(set) var overview: MoneyOverview?
    public private(set) var lens: Lens?
    public private(set) var phase: PublicDataPhase = .idle
    @ObservationIgnored private let service: (any PublicDataService)?
    @ObservationIgnored private let lensRepository: (any LensRepository)?

    public init(service: (any PublicDataService)?, lens: (any LensRepository)? = nil) {
        self.service = service
        lensRepository = lens
    }

    public var isEmpty: Bool {
        guard let overview else { return true }
        return overview.salaries.isEmpty && quotaCents == 0
            && (overview.campaigns?.revenueCents ?? 0) == 0 && overview.revenue == nil
    }

    public var sections: [Section] { Section.order(for: lens) }

    public var showsLensBadge: Bool { lens?.hasChoice == true }

    public var lensNote: String? {
        guard showsLensBadge, let first = sections.first, sections != Section.allCases else {
            return nil
        }
        return String(appLocalized: "Your lens shows \(first.title) first.")
    }

    private var quotaCents: Int {
        guard let quota = overview?.quota else { return 0 }
        return quota.federalDeputiesCents + quota.senatorsCents
    }

    public var hero: Hero? {
        guard let overview, quotaCents > 0 else { return nil }
        let year = String(overview.year)
        return Hero(
            chip: String(appLocalized: "Office allowance · \(year)").uppercased(with: .app),
            value: PublicFormat.compactMoney(cents: quotaCents), cents: quotaCents,
            caption: String(appLocalized: "Spent by federal deputies and senators in \(year)"),
            chamber: PublicFormat.compactMoney(cents: overview.quota.federalDeputiesCents),
            senate: PublicFormat.compactMoney(cents: overview.quota.senatorsCents),
            chamberShare: Double(overview.quota.federalDeputiesCents) / Double(quotaCents))
    }

    public var categories: [AmountBar] {
        MoneyText.bars(
            overview?.quota.byCategory ?? [], id: \.category, title: \.category, cents: \.cents,
            kind: { MoneyKind.category($0.category) })
    }

    public var quotaComposition: [AmountBar] {
        MoneyText.composition(categories, slices: .chartCompositionSlices)
    }

    public var categoriesHeadline: String? {
        guard let first = categories.first else { return nil }
        return String(appLocalized: "\(first.title) was the largest item: \(first.value)")
    }

    public var salaries: [Salary] {
        (overview?.salaries ?? []).map { salary in
            Salary(
                id: salary.office.rawValue, title: salary.office.title,
                law: salary.law ?? PublicFormat.missing,
                symbol: MoneyKind.office(salary.office), cents: salary.monthlyCents,
                value: PublicFormat.money(cents: salary.monthlyCents))
        }
    }

    public var campaigns: MoneyOverview.Campaigns? { overview?.campaigns }

    public var campaignOrigins: [AmountBar] {
        MoneyText.bars(
            campaigns?.byOrigin ?? [], id: \.origin, title: \.origin, cents: \.cents,
            kind: { MoneyKind.origin($0.origin) })
    }

    public var campaignOriginsHeadline: String? {
        guard let first = campaignOrigins.first, first.cents > 0 else { return nil }
        return String(appLocalized: "\(first.percent) came from \(first.title)")
    }

    public var campaignsHeadline: String {
        guard let campaigns else {
            return String(appLocalized: "The electoral court hasn't published campaign money yet.")
        }
        let year = String(campaigns.year)
        let raised = PublicFormat.compactMoney(cents: campaigns.revenueCents)
        return String(appLocalized: "Campaigns in \(year) raised \(raised)")
    }

    public var campaignFigures: (raised: String, spent: String) {
        (
            PublicFormat.compactMoney(cents: campaigns?.revenueCents),
            PublicFormat.compactMoney(cents: campaigns?.expenseCents)
        )
    }

    public var revenue: MoneyOverview.Revenue? { overview?.revenue }

    public var revenueStates: [AmountBar] {
        MoneyText.bars(
            revenue?.byState ?? [], id: \.uf, title: { RaceText.scope($0.uf) }, cents: \.cents,
            kind: { _ in MoneyKind.state })
    }

    public var revenueTiles: [StateTile] { StateTile.tiles(revenue?.byState ?? []) }

    public var revenueHeadline: String {
        guard let revenue else {
            return String(
                appLocalized: "The federal revenue service hasn't closed a full year yet.")
        }
        let total = PublicFormat.compactMoney(cents: revenue.totalCents)
        return String(appLocalized: "Federal revenue in \(String(revenue.year)): \(total)")
    }

    public func sourceLine(for section: Section) -> String {
        let ids: [String] =
            switch section {
            case .quota, .salaries: ["camara", "senado"]
            case .campaigns: ["tse"]
            case .revenue: ["receita"]
            }
        return MoneyText.sourceLine(MoneyText.sources(overview?.sources ?? [], ids: ids))
    }

    public func load() async {
        if overview == nil { phase = .loading }
        phase = await PublicDataPhase.settle(after: phase) {
            lens = try? await lensRepository?.lens()
            guard let service else { throw PublicDataError.unavailable }
            overview = try await service.money()
        }
    }
}
