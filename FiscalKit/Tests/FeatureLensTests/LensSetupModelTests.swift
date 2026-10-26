import FeatureCore
import FiscalData
import FiscalDesignSystem
import FiscalDomain
import FiscalResource
import Foundation
import Testing

@testable import FeatureLens

@MainActor
struct LensSetupModelTests {
    private let lula = PersonCard(
        slug: "lula", name: "Lula", office: .president, uf: "br", party: "PT", photo: nil,
        status: .inOffice)
    private let tabata = PersonCard(
        slug: "tabata-amaral", name: "Tabata Amaral", office: .federalDeputy, uf: "sp",
        party: "PSB", photo: nil, status: .inOffice)

    private func context(saved: Lens? = nil) async throws -> (LensContext, any LensRepository) {
        let repository = try FiscalDatabase.open(inMemory: true).repositories.lens
        if let saved { try await repository.save(saved) }
        let context = LensContext(repository: repository)
        await context.load()
        return (context, repository)
    }

    @Test func walksTheThreeStepsAndSavesOnTheDevice() async throws {
        let (context, repository) = try await context()
        let setup = LensSetupModel(
            context: context, catalog: try ArtCatalog.bundled(), placeCode: nil)
        #expect(context.needsSetup)
        #expect(setup.step == .welcome)
        #expect(!setup.canGoBack)
        await setup.advance()
        #expect(setup.step == .support)
        #expect(!setup.canContinue)
        await setup.toggle(lula)
        #expect(setup.canContinue)
        await setup.advance()
        #expect(setup.step == .themes)
        #expect(setup.draft.isComplete)
        await setup.advance()
        #expect(setup.step == .look)
        #expect(setup.palette == LensPaletteSwatch.named(Lens.suggestedPalette))
        await setup.advance()
        #expect(setup.isFinished)
        #expect(!context.needsSetup)
        let saved = try #require(try await repository.lens())
        #expect(saved.supported == ["lula"])
        #expect(saved == setup.draft)
    }

    @Test func preferNotToSayClearsWhoIsSupported() async throws {
        let (context, _) = try await context()
        let setup = LensSetupModel(context: context, catalog: nil, placeCode: nil)
        await setup.toggle(lula)
        await setup.choosePrefersNotToSay()
        #expect(setup.draft.prefersNotToSay)
        #expect(setup.draft.supported.isEmpty)
        #expect(setup.draft.themes == Array(Theme.neutralOrder.prefix(5)))
        await setup.toggle(tabata)
        #expect(!setup.draft.prefersNotToSay)
    }

    @Test func topicsCanBeReorderedAndRemovedWithinTheLimit() async throws {
        let (context, _) = try await context()
        let setup = LensSetupModel(context: context, catalog: nil, placeCode: nil)
        let first = try #require(setup.draft.themes.first)
        setup.move(first, by: 1)
        #expect(setup.draft.themes[1] == first)
        for theme in setup.draft.themes { setup.remove(theme) }
        #expect(setup.draft.themes.count == Lens.themeRange.lowerBound)
        let other = try #require(setup.otherThemes.first)
        setup.add(other)
        #expect(setup.draft.contains(other))
    }

    @Test func editingOneStepKeepsTheRest() async throws {
        let saved = Lens(
            themes: [.health, .taxes, .security], supported: ["lula"], artCollection: "academia",
            palette: "sea")
        let (context, repository) = try await context(saved: saved)
        let setup = LensSetupModel(
            context: context, catalog: nil, editing: .support, placeCode: nil)
        #expect(setup.step == .support)
        #expect(setup.isLastStep)
        await setup.toggle(tabata)
        await setup.advance()
        #expect(setup.isFinished)
        let edited = try #require(try await repository.lens())
        #expect(edited.supported == ["lula", "tabata-amaral"])
        #expect(edited.themes == saved.themes)
        #expect(edited.palette == saved.palette)
    }

    @Test func palettesComeInMirroredPairs() async throws {
        let (context, _) = try await context()
        let setup = LensSetupModel(context: context, catalog: nil, placeCode: nil)
        let flattened = setup.palettePairs.flatMap { $0 }
        #expect(Set(flattened) == Set(LensPaletteSwatch.allCases))
        for pair in setup.palettePairs {
            #expect(pair.count == 2)
            #expect(pair.first?.mirror == pair.last)
        }
    }
}
