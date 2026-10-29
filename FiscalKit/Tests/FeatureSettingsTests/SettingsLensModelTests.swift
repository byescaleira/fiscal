import FeatureCore
import FiscalData
import FiscalDomain
import FiscalResource
import Foundation
import Testing

@testable import FeatureSettings

private final class CatalogCounter: @unchecked Sendable {
    var reads = 0
}

@MainActor
struct SettingsLensModelTests {
    @Test func loadsTheLensAndTheArtCatalogOnce() async throws {
        let repositories = try FiscalDatabase.open(inMemory: true).repositories
        let context = LensContext(repository: repositories.lens)
        let counter = CatalogCounter()
        let catalog = try ArtCatalog.bundled()
        let model = SettingsLensModel(service: nil) {
            counter.reads += 1
            return catalog
        }
        await model.load(context)
        await model.load(context)
        #expect(context.hasLoaded)
        #expect(model.catalog == catalog)
        #expect(counter.reads == 1)
        #expect(model.summary(for: nil).title == String(appLocalized: "No lens yet"))
    }

    @Test func findsTheFacesOfWhoTheLensSupports() async throws {
        let service = ShowcasePublicData(scenario: .normal)
        let people = try await service.people()
        let picked = try #require(people.first)
        let model = SettingsLensModel(service: service) { throw CocoaError(.fileNoSuchFile) }
        await model.loadFaces(for: [picked.slug], follows: nil)
        #expect(model.faces.map(\.slug) == [picked.slug])
        #expect(model.summary(for: nil).title == SupportedPeople.names([picked]))

        await model.loadFaces(for: [], follows: nil)
        #expect(model.faces.isEmpty)
    }
}
