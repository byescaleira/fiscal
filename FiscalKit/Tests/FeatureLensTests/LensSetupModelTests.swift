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
    private func context(saved: Lens? = nil) async throws -> (LensContext, any LensRepository) {
        let repository = try FiscalDatabase.open(inMemory: true).repositories.lens
        if let saved { try await repository.save(saved) }
        let context = LensContext(repository: repository)
        await context.load()
        return (context, repository)
    }

    @Test func walksTheThreeStepsAndSavesOnTheDevice() async throws {
        let (context, repository) = try await context()
        let setup = LensSetupModel(context: context, catalog: try ArtCatalog.bundled())
        #expect(context.needsSetup)
        #expect(setup.step == .welcome)
        #expect(setup.stepIndex == 0)
        #expect(!setup.canGoBack)
        #expect(!setup.welcomeWorks.isEmpty)
        await setup.advance()
        #expect(setup.step == .stance)
        #expect(setup.stepIndex == 1)
        #expect(!setup.canContinue)
        await setup.advance()
        #expect(setup.step == .stance)
        setup.choose(.center)
        #expect(setup.canContinue)
        await setup.advance()
        #expect(setup.step == .themes)
        #expect(setup.draft.themes == LensPreset.suggested(for: .center).themes)
        await setup.advance()
        #expect(setup.step == .look)
        #expect(setup.isLastStep)
        #expect(setup.progress == 1)
        #expect(setup.palette == .savanna)
        #expect(setup.collection?.id == "civica")
        await setup.advance()
        #expect(setup.isFinished)
        #expect(!context.needsSetup)
        let saved = try #require(try await repository.lens())
        #expect(saved.stance == .center)
        #expect(saved == setup.draft)
    }

    @Test func theSixSidesHaveTheSameWeight() async throws {
        let (context, _) = try await context()
        let setup = LensSetupModel(context: context, catalog: nil)
        #expect(
            setup.stanceChoices == [.right, .centerRight, .center, .centerLeft, .left, .impartial])
        #expect(!setup.stanceChoices.contains(.preferNotToSay))
    }

    @Test func sideSuggestsTopicsAndLookUntilTheyAreTouched() async throws {
        let (context, _) = try await context()
        let setup = LensSetupModel(context: context, catalog: nil)
        setup.choose(.right)
        #expect(setup.draft.themes == LensPreset.suggested(for: .right).themes)
        #expect(setup.palette == .forest)
        setup.choose(.left)
        #expect(setup.draft.themes == LensPreset.suggested(for: .left).themes)
        #expect(setup.palette == .annatto)
        setup.toggle(.health)
        let chosen = setup.draft.themes
        setup.choose(.impartial)
        #expect(setup.draft.themes == chosen)
        #expect(setup.palette == .graphite)
        setup.choose(.sea)
        setup.choose(.right)
        #expect(setup.palette == .sea)
        #expect(setup.draft.stance == .right)
    }

    @Test func preferNotToSayWorksLikeImpartial() async throws {
        let (context, _) = try await context()
        let setup = LensSetupModel(context: context, catalog: nil)
        setup.choose(.preferNotToSay)
        #expect(setup.isChosen(.preferNotToSay))
        #expect(!setup.isChosen(.impartial))
        #expect(setup.draft.themes == LensPreset.suggested(for: .impartial).themes)
        #expect(setup.suggestionText?.contains(PoliticalStance.impartial.title) == true)
    }

    @Test func keepsThreeToFiveTopics() async throws {
        let (context, _) = try await context()
        let setup = LensSetupModel(context: context, catalog: nil)
        await setup.advance()
        setup.choose(.impartial)
        await setup.advance()
        #expect(setup.draft.themes.count == 5)
        #expect(!setup.canToggle(.women))
        for theme in setup.draft.themes.prefix(3) { setup.toggle(theme) }
        #expect(!setup.canContinue)
        await setup.advance()
        #expect(setup.step == .themes)
        setup.toggle(.women)
        #expect(setup.canContinue)
        #expect(setup.themeChoices == Theme.setupChoices)
        setup.showsMoreThemes = true
        #expect(setup.themeChoices.count == Theme.allCases.count)
    }

    @Test func goesBackWithoutLosingTheDraft() async throws {
        let (context, _) = try await context()
        let setup = LensSetupModel(context: context, catalog: nil)
        await setup.advance()
        setup.choose(.centerRight)
        await setup.advance()
        setup.goBack()
        #expect(setup.step == .stance)
        #expect(!setup.movesForward)
        #expect(setup.isChosen(.centerRight))
    }

    @Test func editingOneStepKeepsTheRest() async throws {
        let saved = LensPreset.suggested(for: .right).lens(stance: .right)
        let (context, repository) = try await context(saved: saved)
        let setup = LensSetupModel(context: context, catalog: nil, editing: .stance)
        #expect(setup.step == .stance)
        #expect(setup.isLastStep)
        #expect(!setup.canGoBack)
        #expect(setup.suggestionText == nil)
        setup.choose(.centerLeft)
        await setup.advance()
        #expect(setup.isFinished)
        let edited = try #require(try await repository.lens())
        #expect(edited.stance == .centerLeft)
        #expect(edited.themes == saved.themes)
        #expect(edited.palette == saved.palette)
        #expect(edited.artCollection == saved.artCollection)
    }

    @Test func palettesComeInMirroredPairs() async throws {
        let (context, _) = try await context()
        let setup = LensSetupModel(context: context, catalog: nil)
        let flattened = setup.palettePairs.flatMap { $0 }
        #expect(Set(flattened) == Set(LensPaletteSwatch.allCases))
        for pair in setup.palettePairs {
            #expect(pair.count == 2)
            #expect(pair.first?.mirror == pair.last)
        }
    }
}
