import Testing

@testable import FeatureMine

@MainActor
struct MineModelTests {
    @Test func startsEmptyAndHonest() async {
        let model = MineModel()
        #expect(!model.hasLoaded)
        await model.load()
        #expect(model.hasLoaded)
        #expect(model.isEmpty)
    }
}
