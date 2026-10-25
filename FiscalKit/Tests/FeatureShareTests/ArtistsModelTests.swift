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

    @Test func theLensOnlyReordersTheCollections() async throws {
        let repositories = try FiscalDatabase.open(inMemory: true).repositories
        try await repositories.lens.save(
            Lens(themes: [.health, .taxes, .security], stance: .right, artCollection: "acervo-historico"))
        let adapted = ArtistsModel(lens: repositories.lens)
        await adapted.load()
        let plain = ArtistsModel()
        await plain.load()
        #expect(adapted.collections.first?.id == "acervo-historico")
        #expect(adapted.badgeStance == .right)
        #expect(plain.badgeStance == nil)
        #expect(Set(adapted.collections) == Set(plain.collections))
        #expect(adapted.workCount == plain.workCount)
    }

    @Test func aMissingManifestIsAnHonestEmptyState() async {
        let model = ArtistsModel { throw ArtCatalogError.missingManifest }
        await model.load()
        #expect(model.hasLoaded)
        #expect(model.isEmpty)
        #expect(model.historical.isEmpty)
    }
}
