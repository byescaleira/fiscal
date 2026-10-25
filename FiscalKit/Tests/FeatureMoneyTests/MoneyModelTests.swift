import FiscalData
import FiscalDomain
import Foundation
import Testing

@testable import FeatureMoney

@MainActor
struct MoneyModelTests {
    private let now = Date(timeIntervalSince1970: 1_792_917_720)

    @Test func showsSalariesInReaisWithTheirLaw() async throws {
        let model = MoneyModel(service: ShowcasePublicData(scenario: .normal, now: now))
        await model.load()
        #expect(!model.isEmpty)
        #expect(
            model.salaries.map(\.id) == ["president", "vicePresident", "senator", "federalDeputy"])
        let salary = try #require(model.salaries.first)
        #expect(salary.value.replacingOccurrences(of: "\u{00A0}", with: " ") == "R$ 46.366,19")
        #expect(salary.detail == "Decreto Legislativo 173/2022")
        #expect(model.quota.count == 2)
    }

    @Test func zerosAreAnEmptyStateNotNumbers() async {
        let model = MoneyModel(service: ShowcasePublicData(scenario: .empty, now: now))
        await model.load()
        #expect(model.phase == .loaded)
        #expect(model.isEmpty)
    }

    @Test func reportsAnOutage() async {
        let model = MoneyModel(service: ShowcasePublicData(scenario: .unavailable, now: now))
        await model.load()
        #expect(model.phase == .failed(.unavailable))
        #expect(model.isEmpty)
    }
}
