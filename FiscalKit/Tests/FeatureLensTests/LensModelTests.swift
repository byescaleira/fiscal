import Testing

@testable import FeatureLens

@MainActor
struct LensModelTests {
    @Test func startsEmptyAndHonest() async {
        let model = LensModel()
        #expect(!model.hasLoaded)
        await model.load()
        #expect(model.hasLoaded)
        #expect(model.isEmpty)
    }
}
