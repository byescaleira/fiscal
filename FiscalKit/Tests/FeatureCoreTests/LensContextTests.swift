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
        let mine = Lens.suggested(supported: ["lula"])
        #expect(await context.save(mine))
        context.show(Lens.suggested(supported: ["tabata-amaral"]))
        #expect(context.isPreviewing)
        #expect(context.active?.supported == ["tabata-amaral"])
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
        #expect(await context.save(Lens.suggested(prefersNotToSay: true)))
        #expect(await context.erase())
        #expect(context.saved == nil)
        #expect(context.needsSetup)
        #expect(try await repository.lens() == nil)
    }
}
