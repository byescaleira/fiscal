import FiscalData
import FiscalDomain
import FiscalResource
import Foundation
import Testing

@testable import FeatureShare

@MainActor
struct ArtistsModelTests {
    @Test func showsEveryBundledWorkWithItsCredit() async throws {
        let model = ArtistsModel()
        #expect(!model.hasLoaded)
        await model.load()
        #expect(model.hasLoaded)
        #expect(!model.isEmpty)
        let catalog = try #require(model.catalog)
        let shown = (model.historical + model.openLicense).flatMap(\.works)
        #expect(Set(shown) == Set(catalog.works))
        #expect(model.workCount == catalog.works.count)
        #expect(model.artistCount > 1)
        #expect(model.historical.allSatisfy { $0.works.allSatisfy(\.isPublicDomain) })
        #expect(model.openLicense.allSatisfy { $0.works.allSatisfy { !$0.isPublicDomain } })
    }

    @Test func theCollectionsKeepTheOrderOfTheCatalog() async throws {
        let model = ArtistsModel()
        await model.load()
        let catalog = try #require(model.catalog)
        #expect(model.collections == catalog.collections)
    }

    @Test func eachShelfRemembersItsCollection() async throws {
        let model = ArtistsModel()
        await model.load()
        let sections = model.sections(on: .historical)
        #expect(model.current(on: .historical) == sections.first)
        let last = try #require(sections.last)
        model.show(last.id, on: .historical)
        #expect(model.current(on: .historical) == last)
        #expect(model.current(on: .openLicense) == model.openLicense.first)
    }

    @Test func aMissingManifestIsAnHonestEmptyState() async {
        let model = ArtistsModel { throw ArtCatalogError.missingManifest }
        await model.load()
        #expect(model.hasLoaded)
        #expect(model.isEmpty)
        #expect(model.historical.isEmpty)
    }
}
