import FiscalData
import FiscalDomain
import Foundation
import Testing

@testable import FeatureMoney

@MainActor
struct MoneyModelTests {
    private let now = Date(timeIntervalSince1970: 1_792_917_720)

    private func loaded(
        _ scenario: PublicDataScenario = .normal, stance: PoliticalStance? = nil
    ) async throws -> MoneyModel {
        let repositories = try FiscalDatabase.open(inMemory: true).repositories
        if let stance {
            try await repositories.lens.save(
                Lens(themes: [.health, .taxes, .economy], stance: stance))
        }
        let model = MoneyModel(
            service: ShowcasePublicData(scenario: scenario, now: now), lens: repositories.lens)
        await model.load()
        return model
    }

    @Test func showsSalariesInReaisWithTheirLaw() async throws {
        let model = try await loaded()
        #expect(!model.isEmpty)
        #expect(
            model.salaries.map(\.id) == ["president", "vicePresident", "senator", "federalDeputy"])
        let salary = try #require(model.salaries.first)
        #expect(salary.value.replacingOccurrences(of: "\u{00A0}", with: " ") == "R$ 46.366,19")
        #expect(salary.law == "Decreto Legislativo 173/2022")
        #expect(salary.symbol == "star")
    }

    @Test func theHeroAddsTheChamberAndTheSenate() async throws {
        let model = try await loaded()
        let hero = try #require(model.hero)
        #expect(hero.cents == 19_840_000_000 + 2_715_000_000)
        #expect(hero.chamberShare > 0.87 && hero.chamberShare < 0.89)
        #expect(hero.chip == hero.chip.uppercased(with: .app))
        #expect(hero.value != PublicFormat.missing)
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
        #expect(model.revenueStates.first?.title == "São Paulo")
        #expect(model.sourceLine(for: .campaigns).contains("Tribunal Superior Eleitoral"))
        #expect(!model.sourceLine(for: .campaigns).contains("Câmara"))
        #expect(model.sourceLine(for: .quota).contains("Câmara dos Deputados"))
        #expect(model.sourceLine(for: .revenue).contains("Câmara dos Deputados"))
    }

    @Test func missingCampaignMoneyIsADashNotZero() async throws {
        let model = try await loaded(.empty)
        #expect(model.isEmpty)
        #expect(model.revenue == nil)
        #expect(model.revenueStates.isEmpty)
        let empty = MoneyModel(service: nil)
        #expect(empty.campaignFigures.raised == PublicFormat.missing)
        #expect(empty.campaignFigures.spent == PublicFormat.missing)
        #expect(empty.hero == nil)
    }

    @Test func withoutALensTheOrderIsTheSameForEveryone() async throws {
        let model = try await loaded()
        #expect(model.stance == nil)
        #expect(model.sections == MoneyModel.Section.allCases)
        #expect(model.lensNote == nil)
    }

    @Test func theLensOnlyReordersTheSections() async throws {
        let right = try await loaded(stance: .right)
        let left = try await loaded(stance: .left)
        #expect(right.sections.first == .quota)
        #expect(left.sections.first == .campaigns)
        #expect(Set(right.sections) == Set(left.sections))
        #expect(right.hero == left.hero)
        #expect(right.categories == left.categories)
        #expect(left.lensNote != nil)
    }

    @Test func impartialAndPreferNotToSayKeepTheDefaultOrder() async throws {
        let impartial = try await loaded(stance: .impartial)
        let undisclosed = try await loaded(stance: .preferNotToSay)
        #expect(impartial.sections == MoneyModel.Section.allCases)
        #expect(undisclosed.sections == MoneyModel.Section.allCases)
        #expect(impartial.lensNote == nil)
        #expect(impartial.stance == .impartial)
    }

    @Test func reportsAnOutage() async throws {
        let model = try await loaded(.unavailable)
        #expect(model.phase == .failed(.unavailable))
        #expect(model.isEmpty)
        let offline = try await loaded(.offline)
        #expect(offline.phase == .failed(.offline))
    }
}
