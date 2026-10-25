import Testing

@testable import FeatureToday

@MainActor
struct TodayModelTests {
    @Test func startsEmptyAndHonest() async {
        let model = TodayModel()
        #expect(!model.hasLoaded)
        await model.load()
        #expect(model.hasLoaded)
        #expect(model.isEmpty)
    }
}
