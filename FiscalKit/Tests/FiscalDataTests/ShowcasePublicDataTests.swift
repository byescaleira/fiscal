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
        #expect(Set(people.map(\.office)) == Set(Office.allCases.filter { $0 != .viceGovernor }))
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
}
