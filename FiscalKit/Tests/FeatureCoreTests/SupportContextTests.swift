import FeatureCore
import FiscalData
import FiscalDomain
import Testing

private actor FailingSupport: SupportRepository {
    private(set) var resets = 0

    func support() async throws -> SupportChoice? { throw FiscalError.onFetch }
    func save(_ support: SupportChoice) async throws { throw FiscalError.onSave }
    func reset() async throws { resets += 1 }
}

@MainActor
struct SupportContextTests {
    @Test func aFailedReadReportsAndErasesNothing() async {
        let repository = FailingSupport()
        let context = SupportContext(repository: repository)
        await context.load()
        #expect(context.error == .onFetch)
        #expect(!context.hasLoaded)
        #expect(await repository.resets == 0)
    }

    @Test func savesAndErasesTheChoice() async throws {
        let repository = try FiscalDatabase.open(inMemory: true).repositories.support
        let context = SupportContext(repository: repository)
        await context.load()
        #expect(context.hasLoaded)
        #expect(context.choice.isEmpty)
        let choice = SupportChoice(people: ["pessoa-a"], causes: [.health])
        #expect(await context.save(choice))
        #expect(context.choice == choice)
        #expect(try await repository.support() == choice)
        #expect(await context.erase())
        #expect(context.choice.isEmpty)
        #expect(try await repository.support() == nil)
    }

    @Test func erasingKeepsWhoThePersonFollows() async throws {
        let repositories = try FiscalDatabase.open(inMemory: true).repositories
        let context = SupportContext(repository: repositories.support)
        let card = PersonCard(
            slug: "pessoa-a", name: "Pessoa A", office: .federalDeputy, uf: "sp", party: "PSD",
            photo: nil, status: .inOffice)
        try await repositories.follows.follow(card, at: .now)
        await context.save(SupportChoice(people: ["pessoa-a"]))
        await context.erase()
        #expect(try await repositories.follows.isFollowing(slug: "pessoa-a"))
    }
}
