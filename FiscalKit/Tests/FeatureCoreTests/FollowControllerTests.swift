import FiscalDomain
import Foundation
import Testing

@testable import FeatureCore

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct FollowControllerTests {
    private actor Store: FollowRepository {
        var people: [FollowedPerson] = []
        var fails = false

        func followed() async throws -> [FollowedPerson] { people }
        func isFollowing(slug: String) async throws -> Bool { people.contains { $0.id == slug } }
        func follow(_ card: PersonCard, at date: Date) async throws {
            if fails { throw FiscalError.onSave }
            people.append(FollowedPerson(card: card, followedAt: date))
        }
        func unfollow(slug: String) async throws { people.removeAll { $0.id == slug } }
        func failNext() { fails = true }
    }

    nonisolated private static func card(_ slug: String) -> PersonCard {
        PersonCard(
            slug: slug, name: slug.capitalized, office: .senator, uf: "sp", party: "PL", photo: nil,
            status: .inOffice)
    }

    @Test func togglesFromAnyRow() async {
        let store = Store()
        let follow = FollowController(follows: store, people: { [Self.card("b")] })
        #expect(await follow.toggle(Self.card("a")))
        #expect(follow.isFollowing("a"))
        #expect(await follow.toggle(slug: "b"))
        #expect(await store.people.map(\.id) == ["a", "b"])
        #expect(await !follow.toggle(Self.card("a")))
        #expect(!follow.isFollowing("a"))
    }

    @Test func reloadsWhatTheStoreHas() async throws {
        let store = Store()
        try await store.follow(Self.card("x"), at: .now)
        let follow = FollowController(follows: store)
        await follow.reload()
        #expect(follow.followed == ["x"])
    }

    @Test func keepsTheStateAndReportsWhenSavingFails() async {
        let store = Store()
        await store.failNext()
        let follow = FollowController(follows: store)
        #expect(await !follow.toggle(Self.card("a")))
        #expect(follow.error == .onSave)
        #expect(await !follow.toggle(slug: "unknown"))
    }
}
