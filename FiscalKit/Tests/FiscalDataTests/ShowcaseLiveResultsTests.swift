import FiscalDomain
import Testing

@testable import FiscalData

struct ShowcaseLiveResultsTests {
    @Test func offlineFailsAfterTheFirstLoad() async throws {
        let service = ShowcaseLiveResults(scenario: .offline)
        let first = try await service.races()
        #expect(first.count == 7)
        await #expect(throws: FiscalError.onFetch) { try await service.races() }
    }

    @Test func unavailableAlwaysFails() async {
        let service = ShowcaseLiveResults(scenario: .unavailable)
        await #expect(throws: FiscalError.onFetch) { try await service.races() }
    }

    @Test func progressingAdvancesOnEveryLoad() async throws {
        let service = ShowcaseLiveResults(scenario: .progressing)
        let first = try await service.races()[0].sections.counted
        let second = try await service.races()[0].sections.counted
        #expect(second > first)
    }
}
