import Testing

@testable import FeatureShare

@MainActor
struct ArtistsModelTests {
    @Test func startsEmptyAndHonest() async {
        let model = ArtistsModel()
        #expect(!model.hasLoaded)
        await model.load()
        #expect(model.hasLoaded)
        #expect(model.isEmpty)
    }
}
