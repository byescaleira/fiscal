import FeatureCore
import FiscalData
import FiscalDesignSystem
import FiscalDomain
import FiscalResource
import Foundation
import Testing

@testable import FeatureLens

@MainActor
struct LensModelTests {
    private func context(saved: Lens? = nil) async throws -> (LensContext, any LensRepository) {
        let repository = try FiscalDatabase.open(inMemory: true).repositories.lens
        if let saved { try await repository.save(saved) }
        let context = LensContext(repository: repository)
        await context.load()
        return (context, repository)
    }

    @Test func showsTheSavedLens() async throws {
        let saved = LensPreset.suggested(for: .centerLeft).lens(stance: .centerLeft)
        let (context, _) = try await context(saved: saved)
        let model = LensModel(context: context, catalog: try ArtCatalog.bundled())
        #expect(model.hasLens)
        #expect(model.stanceTitle == PoliticalStance.centerLeft.title)
        #expect(model.themes == saved.themes)
        #expect(model.palette == .ipe)
        #expect(model.collection?.id == "brasil-agora")
        #expect(model.leadWork != nil)
        #expect(!model.otherStances.contains(.centerLeft))
        #expect(model.otherStances.count == PoliticalStance.choices.count - 1)
    }

    @Test func showsADashWithoutALens() async throws {
        let (context, _) = try await context()
        let model = LensModel(context: context, catalog: nil)
        #expect(!model.hasLens)
        #expect(model.stanceTitle == "—")
        #expect(model.paletteTitle == "—")
        #expect(model.themes.isEmpty)
    }

    @Test func anotherLensIsNeverSaved() async throws {
        let saved = LensPreset.suggested(for: .right).lens(stance: .right)
        let (context, repository) = try await context(saved: saved)
        let model = LensModel(context: context, catalog: nil)
        model.preview(.left)
        #expect(model.isPreviewing)
        #expect(model.isPreviewing(.left))
        #expect(context.active?.stance == .left)
        #expect(context.active?.themes == LensPreset.suggested(for: .left).themes)
        #expect(context.saved == saved)
        #expect(try await repository.lens() == saved)
        model.endPreview()
        #expect(!model.isPreviewing)
        #expect(context.active == saved)
    }

    @Test func preferNotToSayHidesTheImpartialLensFromTheOthers() async throws {
        let saved = LensPreset.suggested(for: .preferNotToSay).lens(stance: .preferNotToSay)
        let (context, _) = try await context(saved: saved)
        let model = LensModel(context: context, catalog: nil)
        #expect(!model.otherStances.contains(.impartial))
        #expect(model.otherLensFooter.isEmpty == false)
    }

    @Test func deletingTheChoiceClearsTheDeviceStore() async throws {
        let saved = LensPreset.suggested(for: .center).lens(stance: .center)
        let (context, repository) = try await context(saved: saved)
        let model = LensModel(context: context, catalog: nil)
        model.preview(.right)
        model.isConfirmingErase = true
        await model.erase()
        #expect(!model.isConfirmingErase)
        #expect(!model.hasLens)
        #expect(!context.isPreviewing)
        #expect(context.needsSetup)
        #expect(try await repository.lens() == nil)
    }

    @Test func editorStartsAtTheChosenStep() async throws {
        let saved = LensPreset.suggested(for: .left).lens(stance: .left)
        let (context, _) = try await context(saved: saved)
        let model = LensModel(context: context, catalog: nil)
        model.edit(.themes)
        #expect(model.editing == .themes)
        let editor = model.editor(for: .themes)
        #expect(editor.step == .themes)
        #expect(editor.isEditing)
        #expect(editor.draft == saved)
    }

    @Test func presetsPointToRealPalettesAndCollections() throws {
        let catalog = try ArtCatalog.bundled()
        for stance in PoliticalStance.allCases {
            let preset = LensPreset.suggested(for: stance)
            #expect(LensPaletteSwatch.named(preset.palette) != nil)
            #expect(catalog.collection(id: preset.artCollection) != nil)
        }
    }
}
