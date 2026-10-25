import Testing

@testable import FeatureSearch

@MainActor
struct SearchModelTests {
    @Test func searchesOnlyWithText() {
        let model = SearchModel()
        #expect(!model.isSearching)
        model.query = "   "
        #expect(!model.isSearching)
        model.query = "Tabata"
        #expect(model.isSearching)
    }

    @Test func comparesOnlyTwoOrMorePeople() {
        #expect(CompareModel(slugs: []).isEmpty)
        #expect(CompareModel(slugs: ["tabata-amaral"]).isEmpty)
        #expect(!CompareModel(slugs: ["tabata-amaral", "kim-kataguiri"]).isEmpty)
    }
}
