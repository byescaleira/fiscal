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
        let saved = Lens.suggested(supported: ["lula"])
        let (context, _) = try await context(saved: saved)
        let model = LensModel(context: context, catalog: try ArtCatalog.bundled())
        #expect(model.hasLens)
        #expect(model.supported == ["lula"])
        #expect(model.themes == saved.themes)
        #expect(model.palette == LensPaletteSwatch.named(Lens.suggestedPalette))
        #expect(model.collection?.id == Lens.suggestedArt)
        #expect(model.leadWork != nil)
    }

    @Test func showsADashWithoutALens() async throws {
        let (context, _) = try await context()
        let model = LensModel(context: context, catalog: nil)
        #expect(!model.hasLens)
        #expect(model.heroTitle == "—")
        #expect(model.paletteTitle == "—")
        #expect(model.themes.isEmpty)
    }

    @Test func anotherLensIsNeverSaved() async throws {
        let saved = Lens.suggested(supported: ["lula"])
        let (context, repository) = try await context(saved: saved)
        let model = LensModel(context: context, catalog: nil)
        model.previewNeutral()
        #expect(model.isPreviewing)
        #expect(model.isPreviewingNeutral)
        #expect(context.active?.supported.isEmpty == true)
        #expect(context.saved == saved)
        #expect(try await repository.lens() == saved)
        model.endPreview()
        #expect(!model.isPreviewing)
        #expect(context.active == saved)
    }

    @Test func deletingTheChoiceClearsTheDeviceStore() async throws {
        let saved = Lens.suggested(prefersNotToSay: true)
        let (context, repository) = try await context(saved: saved)
        let model = LensModel(context: context, catalog: nil)
        model.previewNeutral()
        model.isConfirmingErase = true
        await model.erase()
        #expect(!model.isConfirmingErase)
        #expect(!model.hasLens)
        #expect(!context.isPreviewing)
        #expect(context.needsSetup)
        #expect(try await repository.lens() == nil)
    }

    @Test func editorStartsAtTheChosenStep() async throws {
        let saved = Lens.suggested(supported: ["lula"])
        let (context, _) = try await context(saved: saved)
        let model = LensModel(context: context, catalog: nil)
        model.edit(.themes)
        #expect(model.editing == .themes)
        let editor = model.editor(for: .themes)
        #expect(editor.step == .themes)
        #expect(editor.isEditing)
        #expect(editor.draft == saved)
    }

    @Test func theSuggestedLookPointsToARealPaletteAndCollection() throws {
        let catalog = try ArtCatalog.bundled()
        #expect(LensPaletteSwatch.named(Lens.suggestedPalette) != nil)
        #expect(catalog.collection(id: Lens.suggestedArt) != nil)
    }
}
