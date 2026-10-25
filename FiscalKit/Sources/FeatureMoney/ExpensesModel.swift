import FeatureCore
import FiscalDomain
import Foundation
import Observation

@MainActor @Observable
public final class ExpensesModel {
    public struct Header: Equatable, Sendable {
        public let name: String
        public let party: String
        public let detail: String
    }

    public struct Line: Identifiable, Equatable, Sendable {
        public let id: String
        public let supplier: String
        public let category: String
        public let kind: MoneyKind
        public let document: String
        public let isCompany: Bool
        public let value: String
        public let url: URL?
    }

    public struct MonthGroup: Identifiable, Equatable, Sendable {
        public let month: Int
        public let title: String
        public let total: String
        public let lines: [Line]

        public var id: Int { month }
    }

    public let slug: String
    public private(set) var year: Int
    public private(set) var profile: Profile?
    public private(set) var list: ExpenseList?
    public private(set) var phase: PublicDataPhase = .idle
    public var selectedMonth: Int?
    public var categoryFilter: String?
    @ObservationIgnored private let service: (any PublicDataService)?
    @ObservationIgnored private let calendar: Calendar

    public init(
        slug: String, year: Int, service: (any PublicDataService)?,
        calendar: Calendar = FiscalCalendar.current
    ) {
        self.slug = slug
        self.year = year
        self.service = service
        self.calendar = calendar
    }

    public var isEmpty: Bool { (list?.items ?? []).isEmpty }

    public var shareRoute: Route { .share(.expenses(slug: slug, year: year)) }

    public var header: Header? {
        guard let profile else { return nil }
        let place = profile.uf == "br" ? nil : profile.uf.uppercased()
        let detail = [profile.party, place, profile.office.title].compactMap(\.self)
            .joined(separator: " · ")
        return Header(name: profile.name, party: profile.party, detail: detail)
    }

    public var title: String { profile?.name ?? String(appLocalized: "Expenses") }

    public var years: [Int] {
        let published = (profile?.years ?? []).filter { $0.quotaCents != nil }.map(\.year)
        return Array(Set(published + [year]).sorted(by: >).prefix(4)).sorted()
    }

    public var chip: String {
        String(appLocalized: "Office allowance · \(String(year))").uppercased(with: .app)
    }

    public var total: String { PublicFormat.money(cents: list?.totalCents) }

    public var totalCents: Int { list?.totalCents ?? 0 }

    public var receiptsCaption: String {
        let count = PublicFormat.number(list?.items.count)
        return String(appLocalized: "Receipts: \(count)")
    }

    public var months: [MonthBar] {
        let byMonth = Dictionary(
            (list?.byMonth ?? []).map { ($0.month, $0.cents) }, uniquingKeysWith: +)
        let labels = MoneyText.monthLabels(calendar: calendar)
        let names = MoneyText.monthNames(calendar: calendar)
        return (1...12).map { month in
            MonthBar(
                month: month, label: labels[month - 1], name: names[month - 1],
                cents: byMonth[month], value: PublicFormat.money(cents: byMonth[month]))
        }
    }

    public var averageCents: Int? {
        let values = (list?.byMonth ?? []).map(\.cents)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / values.count
    }

    public var averageText: String {
        String(appLocalized: "Monthly average: \(PublicFormat.money(cents: averageCents))")
    }

    public var highlightedMonth: MonthBar? {
        let bars = months
        if let selectedMonth, let bar = bars.first(where: { $0.month == selectedMonth }) {
            return bar
        }
        return bars.last { $0.cents != nil }
    }

    public var peakText: String? {
        guard let peak = months.filter({ $0.cents != nil }).max(by: { $0.reais < $1.reais })
        else { return nil }
        return String(appLocalized: "\(peak.name) had the highest spending: \(peak.value)")
    }

    public var categories: [AmountBar] {
        MoneyText.bars(
            list?.byCategory ?? [], id: \.category, title: \.category, cents: \.cents,
            kind: { MoneyKind.category($0.category) },
            detail: { String(appLocalized: "Receipts: \(PublicFormat.number($0.count))") })
    }

    public var categoryNames: [String] { categories.map(\.title) }

    public var groups: [MonthGroup] {
        let names = MoneyText.monthNames(calendar: calendar)
        let items = (list?.items ?? []).filter {
            categoryFilter == nil || $0.category == categoryFilter
        }
        return Dictionary(grouping: items, by: \.month)
            .sorted { $0.key > $1.key }
            .map { month, expenses in
                MonthGroup(
                    month: month,
                    title: (1...12).contains(month) ? names[month - 1] : PublicFormat.missing,
                    total: PublicFormat.money(cents: expenses.map(\.cents).reduce(0, +)),
                    lines: expenses.sorted { $0.cents > $1.cents }.map(Self.line))
            }
    }

    public var sourceLine: String {
        guard let profile else { return MoneyText.sourceLine([]) }
        let house = profile.office == .senator ? "senado" : "camara"
        return MoneyText.sourceLine(MoneyText.sources(profile.sources, ids: [house]))
    }

    public func load() async {
        if list == nil { phase = .loading }
        phase = await PublicDataPhase.settle(after: phase) {
            guard let service else { throw PublicDataError.unavailable }
            if profile == nil { profile = try? await service.profile(slug: slug) }
            list = try await service.expenses(slug: slug, year: year)
        }
    }

    public func select(year newYear: Int) async {
        guard newYear != year else { return }
        year = newYear
        selectedMonth = nil
        categoryFilter = nil
        list = nil
        await load()
    }

    private static func line(_ expense: Expense) -> Line {
        let document = MoneyText.cnpj(expense.document)
        return Line(
            id: expense.id, supplier: expense.supplier, category: expense.category,
            kind: MoneyKind.category(expense.category),
            document: document.map { String(appLocalized: "CNPJ \($0)") }
                ?? String(appLocalized: "Individual"),
            isCompany: document != nil, value: PublicFormat.money(cents: expense.cents),
            url: expense.url)
    }
}
