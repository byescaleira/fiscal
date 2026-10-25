import FiscalData
import FiscalDomain
import Foundation
import Testing

@testable import FeatureSearch

@MainActor
struct SearchModelTests {
    private let showcase = ShowcasePublicData(
        scenario: .normal, now: Date(timeIntervalSince1970: 1_792_917_720))

    @Test func searchesOnlyWithText() {
        let model = SearchModel(service: showcase)
        #expect(!model.isSearching)
        model.query = "   "
        #expect(!model.isSearching)
        model.query = "Tabata"
        #expect(model.isSearching)
    }

    @Test func findsPeopleIgnoringAccentsAndCase() async {
        let model = SearchModel(service: showcase)
        await model.load()
        #expect(model.phase == .loaded)
        model.query = "tarcisio"
        #expect(model.results.map(\.slug) == ["tarcisio-de-freitas"])
        model.query = "JERÔNIMO"
        #expect(model.results.map(\.slug) == ["jeronimo-rodrigues"])
    }

    @Test func everyWordNarrowsTheResults() async {
        let model = SearchModel(service: showcase)
        await model.load()
        model.query = "psol sp"
        #expect(model.results.map(\.slug) == ["erika-hilton"])
        model.query = "pt"
        #expect(model.results.count > 1)
        model.query = "ninguém com esse nome"
        #expect(model.results.isEmpty)
    }

    @Test func keepsTheIndexInAlphabeticalOrder() async {
        let model = SearchModel(service: showcase)
        await model.load()
        model.query = "sp"
        let names = model.results.map(\.name)
        #expect(names == names.sorted { $0.localizedStandardCompare($1) == .orderedAscending })
    }

    @Test func comparesOnlyTwoOrMorePeople() async {
        #expect(CompareModel(slugs: []).isEmpty)
        #expect(CompareModel(slugs: ["tabata-amaral"]).phase == .loaded)
        let model = CompareModel(slugs: ["tabata-amaral", "kim-kataguiri"], service: showcase)
        #expect(model.isEmpty)
        await model.load()
        #expect(!model.isEmpty)
        #expect(model.rows.map(\.id) == ["attendance", "proposals", "quota"])
        #expect(model.rows.first?.cells.map(\.name) == ["Tabata Amaral", "Kim Kataguiri"])
    }
}
