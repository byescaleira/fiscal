import FeatureCore
import FiscalData
import FiscalDomain
import Testing

@MainActor
struct LensContextTests {
    @Test func asksForTheSetupOnlyAfterLoadingWithoutASide() async throws {
        let repository = try FiscalDatabase.open(inMemory: true).repositories.lens
        let context = LensContext(repository: repository)
        #expect(!context.needsSetup)
        await context.load()
        #expect(context.needsSetup)
        try await repository.save(Lens(themes: [.health, .taxes, .security]))
        let legacy = LensContext(repository: repository)
        await legacy.load()
        #expect(legacy.needsSetup)
        #expect(legacy.saved?.themes == [.health, .taxes, .security])
    }

    @Test func savingEndsAnotherLensAndStaysOnTheDevice() async throws {
        let repository = try FiscalDatabase.open(inMemory: true).repositories.lens
        let context = LensContext(repository: repository)
        await context.load()
        let mine = LensPreset.suggested(for: .centerRight).lens(stance: .centerRight)
        #expect(await context.save(mine))
        context.show(LensPreset.suggested(for: .centerLeft).lens(stance: .centerLeft))
        #expect(context.isPreviewing)
        #expect(context.active?.stance == .centerLeft)
        #expect(try await repository.lens() == mine)
        #expect(await context.save(mine))
        #expect(!context.isPreviewing)
        #expect(context.active == mine)
        #expect(!context.needsSetup)
    }

    @Test func erasingAsksForTheSetupAgain() async throws {
        let repository = try FiscalDatabase.open(inMemory: true).repositories.lens
        let context = LensContext(repository: repository)
        await context.load()
        #expect(await context.save(LensPreset.suggested(for: .left).lens(stance: .left)))
        #expect(await context.erase())
        #expect(context.saved == nil)
        #expect(context.needsSetup)
        #expect(try await repository.lens() == nil)
    }
}
