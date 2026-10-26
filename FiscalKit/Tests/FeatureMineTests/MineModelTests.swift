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

    private static let roster = ShowcaseRoster(
        people: { [] },
        places: {
            [
                Place(code: "3550308", name: "São Paulo", uf: "sp"),
                Place(code: "2111300", name: "São Luís", uf: "ma"),
                Place(code: "1100098", name: "Espigão D'Oeste", uf: "ro"),
                Place(code: "3304557", name: "Rio de Janeiro", uf: "rj"),
                Place(code: "9999999", name: "Cidade Sem Lista", uf: "sp"),
            ]
        },
        city: { code in
            guard code == "1100098" else { return nil }
            let place = Place(code: code, name: "Espigão D'Oeste", uf: "ro")
            return ShowcaseRoster.City(
                place: place,
                officials: ShowcaseRoster.cards(
                    [
                        (.viceMayor, "Vice da Silva", "PL"), (.cityCouncilor, "Zuleide", "PT"),
                        (.mayor, "Prefeito Exemplo", "MDB"), (.cityCouncilor, "Ademir", "PP"),
                    ], in: place),
                note: nil)
        })

    private func makeRosterModel(code: String? = nil) throws -> MineModel {
        MineModel(
            service: ShowcasePublicData(scenario: .normal, now: now, roster: Self.roster),
            follows: nil, memory: try makeMemory(code))
    }

    @Test func aCityShowsItsCityHallAndCouncilBeforeTheState() async throws {
        let memory = try makeMemory()
        let service = ShowcasePublicData(scenario: .normal, now: now)
        let model = MineModel(service: service, follows: nil, memory: memory)
        await model.choose(Place(code: "1200401", name: "Rio Branco", uf: "ac"))
        #expect(memory.code == "1200401")
        #expect(model.place?.isState == false)
        #expect(model.placeTitle == "Rio Branco")
        #expect(model.representatives?.uf == "ac")
        #expect(model.cityRepresentatives?.code == "1200401")
        #expect(
            Array(model.groups.map(\.office).prefix(3)) == [.mayor, .cityCouncilor, .president])
        let hall = try #require(model.groups.first)
        #expect(hall.title == "Prefeitura")
        #expect(hall.people.map(\.office) == [.mayor, .viceMayor])
        #expect(hall.showsOffice)
        #expect(hall.isProminent)
        let council = try #require(model.groups.dropFirst().first)
        #expect(council.title == "Câmara Municipal")
        #expect(council.people.count == 21)
        #expect(!council.showsOffice)
        #expect(model.cityNote == nil)
        #expect(model.representativeCount == 23 + 2)
        #expect(model.sourceText != nil)
        let again = MineModel(service: service, follows: nil, memory: memory)
        await again.load()
        #expect(again.place?.name == "Rio Branco")
        #expect(again.groups.first?.people.first?.name == "Tião Bocalom")
    }

    @Test func theCityHallListsTheMayorFirstAndTheCouncilAlphabetically() async throws {
        let model = try makeRosterModel()
        await model.loadPlaces()
        model.query = "espigao d oeste"
        let place = try #require(model.placeResults.first)
        await model.choose(place)
        #expect(model.groups.first?.people.map(\.name) == ["Prefeito Exemplo", "Vice da Silva"])
        #expect(model.groups.dropFirst().first?.people.map(\.name) == ["Ademir", "Zuleide"])
        #expect(model.groups.dropFirst(2).first?.office == .president)
    }

    @Test func aCityWithoutAPublishedListFallsBackToTheState() async throws {
        let model = try makeRosterModel(code: "9999999")
        await model.load()
        #expect(model.phase == .loaded)
        #expect(model.cityRepresentatives == nil)
        #expect(model.groups.first?.office == .president)
        #expect(model.cityNote != nil)
    }

    @Test func brasiliaExplainsThereIsNoCityHall() async throws {
        let model = try makeModel(code: "5300108")
        await model.load()
        #expect(model.cityRepresentatives?.groups.isEmpty == true)
        #expect(model.cityNote?.contains("Distrito Federal") == true)
        #expect(model.groups.contains { $0.office == .senator })
    }

    @Test func searchesPlacesOnTheDeviceIgnoringAccents() async throws {
        let model = try makeModel()
        await model.loadPlaces()
        #expect(model.placeResults.count == 27)
        #expect(model.placeResults.allSatisfy { $0.isState })
        model.query = "  RIO  "
        #expect(model.placeResults.map(\.code).contains("1200401"))
        model.query = "ms"
        #expect(model.placeResults.first?.code == "ms")
        model.query = "zzz"
        #expect(model.placeResults.isEmpty)
    }

    @Test func findsAnyCityWithoutAccentsOrPunctuation() async throws {
        let model = try makeRosterModel()
        await model.loadPlaces()
        model.query = "sao paulo"
        #expect(model.placeResults.map(\.code) == ["sp", "3550308"])
        model.query = "SAO LUIS"
        #expect(model.placeResults.map(\.code) == ["2111300"])
        model.query = "espigão d'oeste"
        #expect(model.placeResults.map(\.code) == ["1100098"])
        model.query = "espigao"
        #expect(model.placeResults.map(\.code) == ["1100098"])
        let espigao = try #require(model.placeResults.first)
        #expect(model.placeDetail(espigao).hasSuffix("· RO"))
    }

    @Test func anEmptySearchOffersTheCapitalsAndTheWayToFindACity() async throws {
        let model = try makeRosterModel()
        await model.loadPlaces()
        #expect(model.hasCities)
        #expect(model.capitals.map(\.code) == ["3304557", "2111300", "3550308"])
        #expect(!model.isSearchingPlaces)
        #expect(model.placeResults.allSatisfy { $0.isState })
    }

    @Test func aCityOfflineOrEmptyFailsWithoutInventingAList() async throws {
        let offline = try makeModel(.offline, code: "1200401")
        await offline.load()
        #expect(offline.phase == .failed(.offline))
        #expect(offline.groups.isEmpty)
        #expect(offline.cityNote == nil)
        let empty = try makeModel(.empty, code: "1200401")
        await empty.load()
        #expect(empty.groups.isEmpty)
        #expect(empty.cityRepresentatives == nil)
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
