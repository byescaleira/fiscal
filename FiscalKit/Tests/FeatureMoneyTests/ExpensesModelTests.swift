import FeatureCore
import FiscalData
import FiscalDomain
import Foundation
import Testing

@testable import FeatureMoney

@MainActor
struct ExpensesModelTests {
    private let now = Date(timeIntervalSince1970: 1_792_917_720)

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo") ?? .gmt
        return calendar
    }

    private func loaded(
        _ slug: String = "tabata-amaral", year: Int = 2_026,
        scenario: PublicDataScenario = .normal
    ) async -> ExpensesModel {
        let model = ExpensesModel(
            slug: slug, year: year,
            service: ShowcasePublicData(scenario: scenario, now: now, calendar: calendar),
            calendar: calendar)
        await model.load()
        return model
    }

    @Test func loadsTheYearWithThePersonIdentity() async throws {
        let model = await loaded()
        #expect(model.phase == .loaded)
        #expect(!model.isEmpty)
        let header = try #require(model.header)
        #expect(header.name == "Tabata Amaral")
        #expect(header.party == "PSB")
        #expect(header.detail.hasPrefix("PSB · SP · "))
        #expect(model.shareRoute == .share(.expenses(slug: "tabata-amaral", year: 2_026)))
        #expect(model.sourceLine.contains("Câmara dos Deputados"))
        #expect(!model.sourceLine.contains("Senado"))
    }

    @Test func monthsCoverTheWholeYearWithADashForMissingOnes() async throws {
        let model = await loaded()
        #expect(model.months.count == 12)
        let december = try #require(model.months.last)
        #expect(december.cents == nil)
        #expect(december.value == PublicFormat.missing)
        let october = try #require(model.months.first { $0.month == 10 })
        #expect(october.cents != nil)
        #expect(model.highlightedMonth?.month == 10)
        #expect(model.peakText != nil)
        model.selectedMonth = 3
        #expect(model.highlightedMonth?.month == 3)
    }

    @Test func totalsMatchTheReceipts() async throws {
        let model = await loaded()
        let list = try #require(model.list)
        #expect(model.totalCents == list.items.map(\.cents).reduce(0, +))
        #expect(model.categories.map(\.cents).reduce(0, +) == model.totalCents)
        let groups = model.groups
        #expect(groups.map(\.month) == groups.map(\.month).sorted(by: >))
        #expect(groups.flatMap(\.lines).count == list.items.count)
        let average = try #require(model.averageCents)
        #expect(average == list.byMonth.map(\.cents).reduce(0, +) / list.byMonth.count)
    }

    @Test func suppliersShowTheirCNPJOrIndividual() async throws {
        let model = await loaded()
        let lines = model.groups.flatMap(\.lines)
        let company = try #require(lines.first { $0.isCompany })
        #expect(company.document.contains("/0001-"))
        let person = try #require(lines.first { !$0.isCompany })
        #expect(person.document == String(appLocalized: "Individual"))
        #expect(lines.contains { $0.url == nil })
        #expect(lines.contains { $0.url != nil })
    }

    @Test func filteringByKindKeepsOnlyThatKind() async throws {
        let model = await loaded()
        let kind = try #require(model.categoryNames.first)
        model.categoryFilter = kind
        #expect(model.groups.flatMap(\.lines).allSatisfy { $0.category == kind })
        model.categoryFilter = nil
        #expect(model.groups.flatMap(\.lines).count == model.list?.items.count)
    }

    @Test func switchingTheYearReloadsAndClearsTheSelection() async throws {
        let model = await loaded()
        #expect(model.years == [2_023, 2_024, 2_025, 2_026])
        model.selectedMonth = 4
        model.categoryFilter = "Telefonia"
        await model.select(year: 2_025)
        #expect(model.year == 2_025)
        #expect(model.selectedMonth == nil)
        #expect(model.categoryFilter == nil)
        #expect(model.months.allSatisfy { $0.cents != nil })
    }

    @Test func aYearWithoutReceiptsIsEmptyNotZero() async {
        let model = await loaded(year: 2_022)
        #expect(model.phase == .loaded)
        #expect(model.isEmpty)
        #expect(model.averageCents == nil)
        #expect(model.peakText == nil)
    }

    @Test func peopleWithoutTheAllowanceAreNotFound() async {
        let governor = await loaded("tarcisio-de-freitas")
        #expect(governor.phase == .failed(.notFound))
        let offline = await loaded(scenario: .offline)
        #expect(offline.phase == .failed(.offline))
        #expect(offline.header == nil)
    }

    @Test func longNamesStillGroupEveryReceipt() async throws {
        let model = await loaded("jose-roberto-figueiredo", scenario: .longNames)
        #expect(model.phase == .loaded)
        #expect(model.groups.flatMap(\.lines).contains { $0.supplier.count > 60 })
    }
}
