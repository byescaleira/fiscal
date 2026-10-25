import Testing

@testable import FeatureProfile

@MainActor
struct ProfileModelTests {
    @Test func startsEmptyAndHonest() async {
        let model = ProfileModel(slug: "tabata-amaral")
        #expect(!model.hasLoaded)
        await model.load()
        #expect(model.hasLoaded)
        #expect(model.isEmpty)
    }
}
