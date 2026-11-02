import FiscalData
import FiscalDomain
import Foundation
import Testing

@testable import FeatureMoney

@MainActor
struct MoneyModelTests {
    private let now = Date(timeIntervalSince1970: 1_792_917_720)

    private func loaded(
        _ scenario: PublicDataScenario = .normal
    ) async throws -> MoneyModel {
        let model = MoneyModel(service: ShowcasePublicData(scenario: scenario, now: now))
        await model.load()
        return model
    }

    @Test func showsTheMandateCostWithItsActs() async throws {
        let model = try await loaded()
        #expect(!model.isEmpty)
        model.select(scope: "sp")
        let deputy = try #require(model.mandateHighlight)
        #expect(deputy.monthlyCents == 4_636_619 + 4_872_746 + 16_580_607 + 425_300)
        #expect(model.quotaStateBars.first?.uf == "rr")
        #expect(model.mandateActs.contains { $0.act.contains("Decreto Legislativo nº 172/2022") })
    }

    @Test func theAnswerFollowsThePlacePicked() async throws {
        let model = try await loaded()
        model.select(scope: "br")
        let country = try #require(model.answer)
        #expect(country.kicker == country.kicker.uppercased(with: .app))
        #expect(country.value != PublicFormat.missing)
        model.select(scope: "sp")
        let state = try #require(model.answer)
        #expect(state.cents < country.cents)
    }

    @Test func categoriesComeLargestFirstWithTheirSymbol() async throws {
        let model = try await loaded()
        let cents = model.categories.map(\.cents)
        #expect(cents == cents.sorted(by: >))
        #expect(model.categories.first?.kind.symbol == "megaphone")
        #expect(model.categories.contains { $0.kind.symbol == "airplane" })
        #expect(model.categoriesHeadline != nil)
    }

    @Test func campaignsAndRevenueKeepTheirSources() async throws {
        let model = try await loaded()
        #expect(model.campaignOrigins.count == 4)
        #expect(model.revenueTiles.contains { $0.title == "São Paulo" && $0.cents != nil })
        #expect(model.sourceLine(for: .campaigns).contains("Tribunal Superior Eleitoral"))
        #expect(!model.sourceLine(for: .campaigns).contains("Câmara"))
        #expect(model.sourceLine(for: .quota).contains("Câmara dos Deputados"))
        #expect(model.sourceLine(for: .revenue).contains("Câmara dos Deputados"))
    }

    @Test func missingCampaignMoneyIsADashNotZero() async throws {
        let model = try await loaded(.empty)
        #expect(model.isEmpty)
        #expect(model.revenue == nil)
        #expect(model.revenueTiles.allSatisfy { $0.cents == nil })
        let empty = MoneyModel(service: nil)
        #expect(empty.campaignFigures.raised == PublicFormat.missing)
        #expect(empty.campaignFigures.spent == PublicFormat.missing)
        #expect(empty.answer == nil)
    }

    @Test func theSectionsKeepTheDefaultOrder() async throws {
        let model = try await loaded()
        #expect(model.sections == MoneyModel.Section.allCases)
    }

    @Test func reportsAnOutage() async throws {
        let model = try await loaded(.unavailable)
        #expect(model.phase == .failed(.unavailable))
        #expect(model.isEmpty)
        let offline = try await loaded(.offline)
        #expect(offline.phase == .failed(.offline))
    }
}
