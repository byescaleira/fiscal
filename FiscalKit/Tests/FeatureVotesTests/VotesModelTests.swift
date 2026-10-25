import Testing

@testable import FeatureVotes

@MainActor
struct VotesModelTests {
    @Test func startsEmptyAndHonest() async {
        let model = VotesModel()
        #expect(!model.hasLoaded)
        await model.load()
        #expect(model.hasLoaded)
        #expect(model.isEmpty)
    }
}
