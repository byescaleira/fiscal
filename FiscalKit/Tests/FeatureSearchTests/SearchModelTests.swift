import FiscalData
import FiscalDomain
import Foundation
import Synchronization
import Testing

@testable import FeatureSearch

final class MemoryRecentSearches: RecentSearchStore {
    private let storage = Mutex<[String]>([])

    init(_ searches: [String] = []) {
        storage.withLock { $0 = searches }
    }

    func load() -> [String] { storage.withLock { $0 } }

    func save(_ searches: [String]) { storage.withLock { $0 = searches } }
}

@MainActor
struct SearchModelTests {
    private let now = Date(timeIntervalSince1970: 1_792_917_720)

    private func model(
        _ scenario: PublicDataScenario = .normal, lens: (any LensRepository)? = nil,
        recents: MemoryRecentSearches = MemoryRecentSearches()
    ) -> SearchModel {
        let now = now
        return SearchModel(
            service: ShowcasePublicData(scenario: scenario, now: now), lens: lens,
            recents: recents, now: { now })
    }

    @Test func searchesOnlyWithTextOrAFilter() {
        let search = model()
        #expect(!search.isSearching)
        search.query = "   "
        #expect(!search.isSearching)
        search.query = "Tabata"
        #expect(search.isSearching)
        search.query = ""
        search.tokens = [.electedAwaiting]
        #expect(search.isSearching)
    }

    @Test func findsPeopleIgnoringAccentsAndCase() async {
        let search = model()
        await search.load()
        #expect(search.phase == .loaded)
        search.query = "tarcisio"
        #expect(search.results.people.map(\.slug) == ["tarcisio-de-freitas"])
        search.query = "JERÔNIMO"
        #expect(search.results.people.map(\.slug) == ["jeronimo-rodrigues"])
    }

    @Test func everyWordNarrowsTheResults() async {
        let search = model()
        await search.load()
        search.query = "psol sp"
        #expect(search.results.people.map(\.slug) == ["erika-hilton"])
        search.query = "pt"
        #expect(search.results.people.count > 1)
        search.query = "ninguém com esse nome"
        #expect(search.results.isEmpty)
    }

    @Test func findsByOfficeStateNameAndFeminineForms() async {
        let search = model()
        await search.load()
        search.query = "senadora"
        #expect(search.results.people.allSatisfy { $0.office == .senator })
        #expect(!search.results.people.isEmpty)
        search.query = "deputado federal minas"
        #expect(search.results.people.map(\.slug) == ["duda-salabert", "nikolas-ferreira"])
        search.query = "bahia"
        #expect(search.results.people.allSatisfy { $0.uf == "ba" })
        #expect(search.results.places.contains { $0.code == "ba" })
    }

    @Test func groupsPartiesPlacesAndVotes() async {
        let search = model()
        await search.load()
        search.query = "republicanos"
        #expect(search.results.parties.map(\.party) == ["REPUBLICANOS"])
        #expect(search.results.parties.first?.count == 2)
        search.query = "recife"
        #expect(search.results.places.map(\.code) == ["2611606"])
        #expect(search.results.people.isEmpty)
        search.query = "imposto"
        #expect(search.results.votes.map(\.proposition) == ["PL 1873/2026"])
    }

    @Test func keepsPeopleInAlphabeticalOrder() async {
        let search = model()
        await search.load()
        search.query = "sp"
        let names = search.results.people.map(\.name)
        #expect(names.count > 2)
        #expect(names == names.sorted { $0.localizedStandardCompare($1) == .orderedAscending })
    }

    @Test func aCityShowsWhoRepresentsItsState() async throws {
        let search = model()
        await search.load()
        search.query = "recife"
        let recife = try #require(search.results.places.first)
        search.apply(.place(recife))
        #expect(search.query.isEmpty)
        let ufs = Set(search.results.people.map(\.uf))
        #expect(ufs == ["pe", "br"])
        #expect(search.placeNote != nil)
        #expect(search.recents == ["recife"])
    }

    @Test func aTopicFiltersTheRecentVotes() async {
        let search = model()
        await search.load()
        search.apply(.theme(.security))
        #expect(search.results.people.isEmpty)
        #expect(search.results.votes.map(\.proposition) == ["PL 3051/2026"])
    }

    @Test func aPartyAndTheElectedFilterListPeople() async {
        let search = model()
        await search.load()
        search.apply(.party("PSOL"))
        #expect(search.results.people.map(\.slug) == ["erika-hilton"])
        search.apply(.electedAwaiting)
        #expect(search.results.people.map(\.slug) == ["ana-clara-moura"])
        #expect(search.electedAwaiting == 1)
    }

    @Test func remembersRecentSearchesOnlyOnTheDevice() async {
        let store = MemoryRecentSearches(["Kim"])
        let search = model(recents: store)
        await search.load()
        #expect(search.recents == ["Kim"])
        search.query = "Tabata"
        search.record()
        search.query = "kim"
        search.record()
        #expect(store.load() == ["kim", "Tabata"])
        search.clearRecents()
        #expect(store.load().isEmpty)
        #expect(search.recents.isEmpty)
    }

    @Test func recentSearchesStayShortAndUnique() {
        var searches: [String] = []
        for name in ["a", "Lula", "lula", "PT", "PL", "SP", "MG", "BA", "RJ"] {
            searches = RecentSearches.adding(name, to: searches)
        }
        #expect(searches == ["RJ", "BA", "MG", "SP", "PL", "PT"])
    }

    @Test func theLensOrdersTopicsAndSuggestions() async throws {
        let repositories = try FiscalDatabase.open(inMemory: true).repositories
        let plain = model(lens: repositories.lens)
        await plain.load()
        #expect(plain.themes == SearchModel.defaultThemes)
        #expect(!plain.isLensAdapted)
        #expect(!plain.comparesFirst)
        try await repositories.lens.save(
            Lens(themes: [.environment, .health, .rights], prefersNotToSay: true))
        let impartial = model(lens: repositories.lens)
        await impartial.load()
        #expect(impartial.themes == [.environment, .health, .rights])
        #expect(impartial.isLensAdapted)
        #expect(impartial.comparesFirst)
        try await repositories.lens.save(
            Lens(themes: [.taxes, .security, .economy], supported: ["lula"]))
        let right = model(lens: repositories.lens)
        await right.load()
        #expect(!right.comparesFirst)
        #expect(right.suggestions == impartial.suggestions)
    }

    @Test func suggestsComparisonsWithinTheSameOfficeAndState() async {
        let search = model()
        await search.load()
        let suggestions = search.suggestions
        #expect(
            suggestions.map(\.id) == ["federalDeputy-mg", "federalDeputy-sp", "stateDeputy-sp"])
        #expect(
            suggestions[1].slugs == ["erika-hilton", "kim-kataguiri", "tabata-amaral"])
    }

    @Test func showsTheElectionTimeline() {
        let search = model()
        let elections = search.elections
        #expect(elections.map(\.year) == [2_026, 2_022, 2_018])
        #expect(elections[0].isCurrent)
        #expect(elections[0].liveRound?.number == 2)
        #expect(elections[0].rounds.first?.status == .past)
        #expect(elections[1].rounds.allSatisfy { $0.status == .past })
        #expect(!elections[1].isCurrent)
    }

    @Test func anEmptyOrOfflineIndexIsHonest() async {
        let empty = model(.empty)
        await empty.load()
        #expect(empty.phase == .loaded)
        empty.query = "lula"
        #expect(empty.results.isEmpty)
        #expect(empty.suggestions.isEmpty)
        let offline = model(.offline)
        await offline.load()
        #expect(offline.phase == .failed(.offline))
        #expect(offline.elections.count == 3)
        let missing = SearchModel(service: nil, recents: nil)
        await missing.load()
        #expect(missing.phase.error == .unavailable)
    }
}
