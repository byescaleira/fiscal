import FeatureCore
import FiscalData
import FiscalDomain
import Foundation
import Testing

@testable import FeatureMine

@MainActor
struct MineModelTests {
    private let now = Date(timeIntervalSince1970: 1_792_917_720)

    private func makeMemory(_ code: String? = nil) throws -> MinePlaceMemory {
        let defaults = try #require(UserDefaults(suiteName: "mine-\(UUID().uuidString)"))
        let memory = MinePlaceMemory(defaults: defaults)
        memory.code = code
        return memory
    }

    private func makeModel(
        _ scenario: PublicDataScenario = .normal, code: String? = nil,
        follows: (any FollowRepository)? = nil
    ) throws -> MineModel {
        MineModel(
            service: ShowcasePublicData(scenario: scenario, now: now), follows: follows,
            memory: try makeMemory(code))
    }

    @Test func startsEmptyAndHonest() async throws {
        let follows = try FiscalDatabase.open(inMemory: true).repositories.follows
        let model = try makeModel(follows: follows)
        #expect(!model.hasLoaded)
        await model.load()
        #expect(model.hasLoaded)
        #expect(model.isEmpty)
        #expect(!model.hasPlace)
        #expect(model.phase == .idle)
        #expect(model.groups.isEmpty)
        #expect(model.shareRoute == nil)
    }

    @Test func listsWhoTheProfileFollowsInAlphabeticalOrder() async throws {
        let follows = try FiscalDatabase.open(inMemory: true).repositories.follows
        try await follows.follow(
            PersonCard(
                slug: "lula", name: "Lula", office: .president, uf: "br", party: "PT", photo: nil,
                status: .inOffice), at: .now)
        try await follows.follow(
            PersonCard(
                slug: "damares-alves", name: "Damares Alves", office: .senator, uf: "df",
                party: "REPUBLICANOS", photo: nil, status: .inOffice), at: .now)
        let model = try makeModel(follows: follows)
        await model.load()
        #expect(model.followed.map(\.card.slug) == ["damares-alves", "lula"])
        let president = try #require(model.followed.last)
        #expect(!model.detail(for: president).contains("BR"))
        #expect(
            model.detail(for: try #require(model.followed.first)).hasSuffix("REPUBLICANOS · DF"))
    }

    @Test func choosingAStateGroupsItsRepresentativesAlphabetically() async throws {
        let model = try makeModel()
        await model.choose(Place(code: "sp", name: "São Paulo", uf: "sp"))
        #expect(model.phase == .loaded)
        #expect(model.hasPlace)
        #expect(model.placeTitle == "São Paulo")
        #expect(model.ufText == "SP")
        #expect(
            model.groups.map(\.office) == [
                .president, .vicePresident, .federalDeputy, .governor, .stateDeputy,
            ])
        let deputies = try #require(model.groups.first { $0.office == .federalDeputy })
        #expect(deputies.people.map(\.name) == ["Erika Hilton", "Kim Kataguiri", "Tabata Amaral"])
        #expect(!deputies.isSingle)
        #expect(deputies.header.hasSuffix("· 3"))
        #expect(model.groups.first { $0.office == .governor }?.isSingle == true)
        #expect(model.representativeCount == 8)
        #expect(model.shareRoute == .share(.representatives(uf: "sp")))
        #expect(model.sourceText != nil)
        #expect(model.cityNote == nil)
    }

    @Test func aCityResolvesToItsStateAndIsRemembered() async throws {
        let memory = try makeMemory()
        let service = ShowcasePublicData(scenario: .normal, now: now)
        let model = MineModel(service: service, follows: nil, memory: memory)
        await model.choose(Place(code: "3106200", name: "Belo Horizonte", uf: "mg"))
        #expect(memory.code == "3106200")
        #expect(model.place?.isState == false)
        #expect(model.placeTitle == "Belo Horizonte")
        #expect(model.representatives?.uf == "mg")
        #expect(model.cityNote != nil)
        let again = MineModel(service: service, follows: nil, memory: memory)
        await again.load()
        #expect(again.place?.name == "Belo Horizonte")
        #expect(again.groups.flatMap(\.people).contains { $0.slug == "nikolas-ferreira" })
    }

    @Test func searchesPlacesOnTheDeviceIgnoringAccents() async throws {
        let model = try makeModel()
        await model.loadPlaces()
        #expect(model.placeResults.count == 27)
        #expect(model.placeResults.allSatisfy(\.isState))
        model.query = "sao"
        let results = model.placeResults
        #expect(results.first?.code == "sp")
        #expect(results.contains { $0.code == "3550308" })
        model.query = "  BELO  "
        #expect(model.placeResults.map(\.code) == ["3106200"])
        model.query = "ms"
        #expect(model.placeResults.first?.code == "ms")
        model.query = "zzz"
        #expect(model.placeResults.isEmpty)
    }

    @Test func offlineKeepsWhoYouFollow() async throws {
        let follows = try FiscalDatabase.open(inMemory: true).repositories.follows
        try await follows.follow(
            PersonCard(
                slug: "lula", name: "Lula", office: .president, uf: "br", party: "PT", photo: nil,
                status: .inOffice), at: .now)
        let model = try makeModel(.offline, code: "sp", follows: follows)
        await model.load()
        #expect(model.phase == .failed(.offline))
        #expect(model.followed.count == 1)
        #expect(model.groups.isEmpty)
    }

    @Test func anEmptyLoadSaysNothingIsPublished() async throws {
        let model = try makeModel(.empty, code: "sp")
        await model.load()
        #expect(model.hasNoRepresentatives)
        #expect(model.shareRoute == nil)
    }

    @Test func longNamesStayInAlphabeticalOrder() async throws {
        let model = try makeModel(.longNames, code: "pe")
        await model.load()
        let senators = try #require(model.groups.first { $0.office == .senator })
        #expect(
            senators.people.map(\.name) == [
                "Humberto Costa", "Maria da Conceição Albuquerque de Vasconcellos",
            ])
    }

    @Test func forgettingThePlaceClearsTheDevice() async throws {
        let memory = try makeMemory("sp")
        let model = MineModel(
            service: ShowcasePublicData(scenario: .normal, now: now), follows: nil, memory: memory)
        await model.load()
        #expect(!model.groups.isEmpty)
        model.forgetPlace()
        #expect(memory.code == nil)
        #expect(model.groups.isEmpty)
        #expect(model.phase == .idle)
    }

    @Test func statusOnlyShowsWhenNotInOffice() throws {
        let model = try makeModel()
        let awaiting = PersonCard(
            slug: "a", name: "Ana", office: .federalDeputy, uf: "ba", party: "PSD", photo: nil,
            status: .electedAwaiting)
        let serving = PersonCard(
            slug: "b", name: "Bia", office: .federalDeputy, uf: "ba", party: "PSD", photo: nil,
            status: .inOffice)
        #expect(model.status(of: awaiting) != nil)
        #expect(model.status(of: serving) == nil)
        #expect(model.accessibilityLabel(for: serving).hasPrefix("Bia, PSD"))
    }
}
