import Testing

@testable import FeatureMoney

@MainActor
struct MoneyModelTests {
    @Test func startsEmptyAndHonest() async {
        let model = MoneyModel()
        #expect(!model.hasLoaded)
        await model.load()
        #expect(model.hasLoaded)
        #expect(model.isEmpty)
    }
}
