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

    private actor SlowStore: FollowRepository {
        var people: [FollowedPerson] = []
        var calls = 0
        private var gate: CheckedContinuation<Void, Never>?

        func followed() async throws -> [FollowedPerson] { people }
        func isFollowing(slug: String) async throws -> Bool { people.contains { $0.id == slug } }
        func follow(_ card: PersonCard, at date: Date) async throws {
            calls += 1
            await withCheckedContinuation { gate = $0 }
            people.append(FollowedPerson(card: card, followedAt: date))
        }
        func unfollow(slug: String) async throws { people.removeAll { $0.id == slug } }
        func isWaiting() -> Bool { gate != nil }
        func open() {
            gate?.resume()
            gate = nil
        }
    }

    private final class WidgetCalls {
        var unfollowed: [String?] = []
    }

    nonisolated private static func card(_ slug: String) -> PersonCard {
        PersonCard(
            slug: slug, name: slug.capitalized, office: .senator, uf: "sp", party: "PL", photo: nil,
            status: .inOffice)
    }

    @Test func togglesFromAnyRow() async {
        let store = Store()
        let follow = FollowController(
            follows: store, people: { [Self.card("b")] }, widget: { _ in })
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
        let follow = FollowController(follows: store, widget: { _ in })
        await follow.reload()
        #expect(follow.followed == ["x"])
    }

    @Test func keepsTheStateAndReportsWhenSavingFails() async {
        let store = Store()
        await store.failNext()
        let follow = FollowController(follows: store, widget: { _ in })
        #expect(await !follow.toggle(Self.card("a")))
        #expect(follow.error == .onSave)
        #expect(await !follow.toggle(slug: "unknown"))
    }

    @Test func refreshesTheWidgetAndForgetsWhoWasUnfollowed() async {
        let calls = WidgetCalls()
        let follow = FollowController(follows: Store(), widget: { calls.unfollowed.append($0) })
        await follow.toggle(Self.card("a"))
        await follow.toggle(Self.card("a"))
        #expect(calls.unfollowed == [nil, "a"])
    }

    @Test func ignoresASecondTapWhileTheFirstIsSaving() async {
        let store = SlowStore()
        let follow = FollowController(follows: store, widget: { _ in })
        let first = Task { await follow.toggle(Self.card("a")) }
        while await !store.isWaiting() { await Task.yield() }
        #expect(await !follow.toggle(Self.card("a")))
        await store.open()
        #expect(await first.value)
        #expect(await store.calls == 1)
        #expect(follow.isFollowing("a"))
    }
}
