import FeatureCore
import FiscalData
import FiscalDomain
import Foundation
import Testing

@testable import FeatureRegion

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct FollowingModelTests {
    private let now = Date(timeIntervalSince1970: 1_792_917_720)

    private func makeModel(
        _ scenario: PublicDataScenario = .normal, code: String? = nil,
        follows: (any FollowRepository)?, inviteDefaults: UserDefaults = .standard
    ) throws -> FollowingModel {
        let defaults = try #require(UserDefaults(suiteName: "mine-\(UUID().uuidString)"))
        let memory = RegionPlaceMemory(defaults: defaults)
        memory.code = code
        return FollowingModel(
            service: ShowcasePublicData(scenario: scenario, now: now), follows: follows,
            memory: memory, inviteDefaults: inviteDefaults)
    }

    private static func card(_ slug: String, _ name: String) -> PersonCard {
        PersonCard(
            slug: slug, name: name, office: .federalDeputy, uf: "sp", party: "PSD", photo: nil,
            status: .inOffice)
    }

    @Test func startsEmptyAndHonest() async throws {
        let follows = try FiscalDatabase.open(inMemory: true).repositories.follows
        let model = try makeModel(follows: follows)
        #expect(!model.hasLoaded)
        await model.load()
        #expect(model.hasLoaded)
        #expect(model.isEmpty)
        #expect(!model.hasPlace)
        #expect(model.suggestions.isEmpty)
    }

    @Test func listsWhoTheProfileFollowsInAlphabeticalOrder() async throws {
        let follows = try FiscalDatabase.open(inMemory: true).repositories.follows
        try await follows.follow(Self.card("lula", "Lula"), at: now)
        try await follows.follow(Self.card("damares-alves", "Damares Alves"), at: now)
        let model = try makeModel(follows: follows)
        await model.load()
        #expect(model.cards.map(\.slug) == ["damares-alves", "lula"])
    }

    @Test func unfollowingLeavesTheListAndComesBackAsASuggestion() async throws {
        let follows = try FiscalDatabase.open(inMemory: true).repositories.follows
        let model = try makeModel(code: "sp", follows: follows)
        await model.load()
        let first = try #require(model.suggestions.first)
        try await follows.follow(first, at: now)
        await model.load()
        #expect(model.cards.map(\.slug) == [first.slug])
        #expect(!model.suggestions.map(\.slug).contains(first.slug))
        try await follows.unfollow(slug: first.slug)
        await model.load()
        #expect(model.isEmpty)
        #expect(model.suggestions.map(\.slug).contains(first.slug))
    }

    @Test func suggestsRepresentativesNotFollowedInOfficeOrder() async throws {
        let follows = try FiscalDatabase.open(inMemory: true).repositories.follows
        let model = try makeModel(code: "sp", follows: follows)
        await model.load()
        #expect(model.hasPlace)
        #expect(!model.suggestions.isEmpty)
        #expect(model.suggestions.count <= FollowingModel.suggestionLimit)
        let ranks = model.suggestions.map { FollowingModel.rank($0.office) }
        #expect(ranks == ranks.sorted())
        #expect(Set(model.suggestions.map(\.slug)).count == model.suggestions.count)
    }

    @Test func offlineKeepsWhoYouFollow() async throws {
        let follows = try FiscalDatabase.open(inMemory: true).repositories.follows
        try await follows.follow(Self.card("lula", "Lula"), at: now)
        let model = try makeModel(.offline, code: "sp", follows: follows)
        await model.load()
        #expect(model.cards.count == 1)
        #expect(model.suggestions.isEmpty)
    }

    @Test func invitesToShareOnlyAfterTheFirstFollowUntilDismissed() async throws {
        let invites = "invite-\(UUID().uuidString)"
        defer { UserDefaults.standard.removePersistentDomain(forName: invites) }
        let inviteDefaults = try #require(UserDefaults(suiteName: invites))
        let follows = try FiscalDatabase.open(inMemory: true).repositories.follows
        let model = try makeModel(follows: follows, inviteDefaults: inviteDefaults)
        await model.load()
        #expect(!model.showsInvite)
        try await follows.follow(Self.card("c", "Caio"), at: now)
        await model.load()
        #expect(model.showsInvite)
        #expect(model.inviteRoute == .share(.following))
        model.dismissInvite()
        #expect(!model.showsInvite)
        #expect(inviteDefaults.bool(forKey: FollowingModel.inviteKey))
        let reopened = try makeModel(follows: follows, inviteDefaults: inviteDefaults)
        await reopened.load()
        #expect(!reopened.isEmpty)
        #expect(!reopened.showsInvite)
    }
}
