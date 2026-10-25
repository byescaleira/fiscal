import FiscalDomain
import Foundation
import Testing

@testable import FiscalData

struct ShowcasePublicDataTests {
    private let now = Date(timeIntervalSince1970: 1_792_917_720)

    private func showcase(_ scenario: PublicDataScenario) -> ShowcasePublicData {
        ShowcasePublicData(scenario: scenario, now: now)
    }

    @Test func readsTheScenarioFromTheLaunchArgument() throws {
        let defaults = try #require(UserDefaults(suiteName: "ShowcasePublicDataTests.\(UUID())"))
        #expect(PublicDataScenario.fromLaunchArguments(defaults) == nil)
        defaults.set("longNames", forKey: PublicDataScenario.launchKey)
        #expect(PublicDataScenario.fromLaunchArguments(defaults) == .longNames)
        #expect(PublicDataScenario.named("nope") == nil)
    }

    @Test func normalCoversBothSidesInAlphabeticalOrder() async throws {
        let people = try await showcase(.normal).people()
        let names = people.map(\.name)
        #expect(names == names.sorted { $0.localizedStandardCompare($1) == .orderedAscending })
        #expect(
            Set(people.map(\.party)).isSuperset(of: ["PT", "PL", "PSOL", "NOVO", "UNIÃO", "PSB"]))
        #expect(
            Set(people.map(\.office))
                == Set(Office.allCases.filter { $0 != .viceGovernor && !$0.isMunicipal }))
        #expect(Set(people.map(\.status)) == Set(PersonStatus.allCases))
    }

    @Test func everyPersonInTheIndexHasAProfile() async throws {
        let data = showcase(.normal)
        for card in try await data.people() {
            let profile = try await data.profile(slug: card.slug)
            #expect(profile.card == card)
            #expect(!profile.sources.isEmpty)
        }
    }

    @Test func activityOnlyExistsWhereItIsPublished() async throws {
        let data = showcase(.normal)
        let deputy = try await data.expenses(slug: "tabata-amaral", year: 2_026)
        #expect(deputy.totalCents == deputy.items.map(\.cents).reduce(0, +))
        #expect(deputy.byCategory.map(\.cents).reduce(0, +) == deputy.totalCents)
        await #expect(throws: PublicDataError.notFound) {
            try await data.expenses(slug: "eduardo-suplicy", year: 2_026)
        }
        let governor = try await data.profile(slug: "tarcisio-de-freitas")
        #expect(governor.numbers.attendance == nil)
        #expect(governor.salary == nil)
        #expect(governor.coverage(of: "votes") == .notPublished)
    }

    @Test func groupsTheRepresentativesOfAState() async throws {
        let place = try await showcase(.normal).representatives(uf: "SP")
        #expect(place.name == "São Paulo")
        #expect(place.groups.first?.office == .president)
        #expect(place.groups.allSatisfy { !$0.people.isEmpty })
        #expect(place.groups.contains { $0.office == .stateDeputy && $0.people.count == 2 })
    }

    @Test func everyRecentVoteOpensAndAddsUp() async throws {
        let data = showcase(.normal)
        let votes = try await data.recentVotes()
        #expect(Set(votes.map(\.house)) == [.camara, .senado])
        for vote in votes {
            let detail = try await data.vote(id: vote.id)
            #expect(detail.vote == vote)
            let counted = detail.parties.map { $0.yes + $0.no + $0.others }.reduce(0, +)
            #expect(counted == detail.people.count)
        }
        await #expect(throws: PublicDataError.notFound) { try await data.vote(id: "missing") }
    }

    @Test func emptyIsHonest() async throws {
        let data = showcase(.empty)
        #expect(try await data.people().isEmpty)
        #expect(try await data.recentVotes().isEmpty)
        #expect(try await data.today().events.isEmpty)
        #expect(try await data.agenda().houses.isEmpty)
        #expect(try await data.money().revenue == nil)
        #expect(try await data.representatives(uf: "sp").groups.isEmpty)
        await #expect(throws: PublicDataError.notFound) { try await data.profile(slug: "lula") }
    }

    @Test func offlineAndUnavailableFailEveryCall() async {
        await #expect(throws: PublicDataError.offline) { try await showcase(.offline).today() }
        await #expect(throws: PublicDataError.offline) { try await showcase(.offline).people() }
        await #expect(throws: PublicDataError.unavailable) {
            try await showcase(.unavailable).money()
        }
    }

    @Test func longNamesStretchTheLayout() async throws {
        let data = showcase(.longNames)
        let longest = try await data.people().map(\.name.count).max() ?? 0
        #expect(longest >= 45)
        let vote = try #require(try await data.recentVotes().first)
        #expect(vote.summary.count > 150)
    }

    @Test func survivesTheContractEncoding() async throws {
        let data = showcase(.normal)
        let profile = try await data.profile(slug: "nikolas-ferreira")
        let encoded = try PublicDataCoding.encoder().encode(profile)
        #expect(try PublicDataCoding.decoder().decode(Profile.self, from: encoded) == profile)
        let money = try await data.money()
        let roundTrip = try PublicDataCoding.decoder().decode(
            MoneyOverview.self, from: PublicDataCoding.encoder().encode(money))
        #expect(roundTrip == money)
    }

    @Test func aCapitalOpensWithItsCityHallAndCouncil() async throws {
        let data = showcase(.normal)
        #expect(try await data.places().contains { $0.code == "1200401" })
        let city = try #require(try await data.cityRepresentatives(code: "1200401"))
        #expect(city.name == "Rio Branco")
        #expect(city.uf == "ac")
        #expect(city.groups.map(\.title) == ["Prefeitura", "Câmara Municipal"])
        #expect(city.groups.allSatisfy { $0.level == .city })
        let hall = try #require(city.groups.first)
        #expect(hall.people.map(\.name) == ["Tião Bocalom", "Alysson Bestene"])
        #expect(hall.people.map(\.office) == [.mayor, .viceMayor])
        let council = try #require(city.groups.last).people.map(\.name)
        #expect(council.count == 21)
        #expect(council == council.sorted { $0.localizedStandardCompare($1) == .orderedAscending })
        #expect(city.sources.map(\.id) == [Source.municipalElectionID])
        let mayor = try await data.profile(slug: try #require(hall.people.first).slug)
        #expect(mayor.office == .mayor)
        #expect(mayor.numbers.assetsCents == nil)
        #expect(mayor.mandate?.end == CalendarDay(year: 2_028, month: 12, day: 31))
    }

    @Test func citiesWithoutAnElectionExplainWhy() async throws {
        let data = showcase(.normal)
        let brasilia = try #require(try await data.cityRepresentatives(code: "5300108"))
        #expect(brasilia.groups.isEmpty)
        #expect(brasilia.note?.contains("Distrito Federal") == true)
        #expect(try await data.cityRepresentatives(code: "9999999") == nil)
        #expect(try await showcase(.empty).cityRepresentatives(code: "1200401") == nil)
        await #expect(throws: PublicDataError.offline) {
            try await showcase(.offline).cityRepresentatives(code: "1200401")
        }
    }

    @Test func longNamesReachTheCityCouncil() async throws {
        let data = showcase(.longNames)
        let city = try #require(try await data.cityRepresentatives(code: "1400100"))
        let council = try #require(city.groups.last).people
        let long = try #require(council.first { $0.name.count > 45 })
        #expect(long.slug.hasPrefix("teste-"))
        #expect(try await data.profile(slug: long.slug).name == long.name)
    }

    @Test func theFullRosterAddsEveryoneWithoutDuplicatingTheCurated() async throws {
        let roster = ShowcaseRoster(
            people: {
                [
                    PersonCard(
                        slug: "flavio-bolsonaro", name: "Flávio Bolsonaro", office: .senator,
                        uf: "rj", party: "PL", photo: nil, status: .inOffice),
                    PersonCard(
                        slug: "tarcisio", name: "Tarcísio", office: .governor, uf: "sp",
                        party: "REPUBLICANOS", photo: nil, status: .inOffice),
                    PersonCard(
                        slug: "lula", name: "Lula", office: .president, uf: "br", party: "PT",
                        photo: nil, status: .inOffice),
                ]
            }, places: { [] }, city: { _ in nil })
        let data = ShowcasePublicData(scenario: .normal, now: now, roster: roster)
        let people = try await data.people()
        #expect(people.filter { $0.slug == "lula" }.count == 1)
        #expect(!people.contains { $0.slug == "tarcisio" })
        #expect(people.contains { $0.slug == "flavio-bolsonaro" })
        let rio = try await data.representatives(uf: "rj")
        #expect(rio.groups.contains { $0.people.contains { $0.slug == "flavio-bolsonaro" } })
        let flavio = try await data.profile(slug: "flavio-bolsonaro")
        #expect(flavio.numbers.attendance == nil)
        #expect(flavio.numbers.lastElectionVotes == nil)
        await #expect(throws: PublicDataError.notFound) {
            try await data.votes(slug: "flavio-bolsonaro", year: 2_026)
        }
        #expect(try await data.votes(slug: "tabata-amaral", year: 2_026).total > 0)
    }

    @Test func rosterSlugsAreStableAndUniqueInsideACity() {
        let place = Place(code: "2611606", name: "Recife", uf: "pe")
        let cards = ShowcaseRoster.cards(
            [(.cityCouncilor, "Ana Lúcia", "PT"), (.cityCouncilor, "Ana Lucia", "PL")], in: place)
        #expect(cards.map(\.slug) == ["ana-lucia-2611606", "ana-lucia-2611606-2"])
        #expect(ShowcaseRoster.code(in: "ana-lucia-2611606-2") == "2611606")
        #expect(ShowcaseRoster.code(in: "lula") == nil)
    }
}
