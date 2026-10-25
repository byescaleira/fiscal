import FiscalData
import FiscalDomain
import Testing

@testable import FeatureHome

@MainActor
struct HomeModelTests {
    @Test func showsTheEmptyStateOnlyAfterLoading() async throws {
        let home = HomeModel(repositories: try FiscalDatabase.open(inMemory: true).repositories)
        #expect(!home.isEmpty)
        await home.load()
        #expect(home.isEmpty)
        #expect(home.count == 0)
    }

    @Test func countsTheSavedItems() async throws {
        let repositories = try FiscalDatabase.open(inMemory: true).repositories
        try await repositories.items.save(Item(title: "First"))
        try await repositories.items.save(Item(title: "Second"))
        let home = HomeModel(repositories: repositories)
        await home.load()
        #expect(!home.isEmpty)
        #expect(home.count == 2)
        #expect(home.detail(for: home.items[0]).isEmpty == false)
    }
}
