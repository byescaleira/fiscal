import AppIntents
import FeatureCore
import FiscalDomain
import Foundation
import Testing

@testable import AppShell

@Suite(.timeLimit(.minutes(1)))
struct FollowIntentTests {
    private actor Store: FollowRepository {
        var people: [FollowedPerson] = []

        func followed() async throws -> [FollowedPerson] { people }
        func isFollowing(slug: String) async throws -> Bool { people.contains { $0.id == slug } }
        func follow(_ card: PersonCard, at date: Date) async throws {
            people.append(FollowedPerson(card: card, followedAt: date))
        }
        func unfollow(slug: String) async throws { people.removeAll { $0.id == slug } }
    }

    private static let fulana = PersonCard(
        slug: "fulana", name: "Fulana", office: .senator, uf: "sp", party: "PL", photo: nil,
        status: .inOffice)

    private static func releaseStore(_ state: UpdateState?) throws -> AppReleaseStore {
        let store = AppReleaseStore(
            directory: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString))
        try store.write(AppReleaseCache(simulated: state))
        return store
    }

    @MainActor
    private final class WidgetCalls {
        var unfollowed: [String?] = []
    }

    private static func writer(
        _ store: Store, release: AppReleaseStore, index: [PersonCard] = [fulana],
        calls: WidgetCalls? = nil
    ) -> FollowIntentWriter {
        FollowIntentWriter(
            store: release,
            people: { slugs in index.filter { slugs.contains($0.slug) } },
            follows: { store },
            widget: { calls?.unfollowed.append($0) })
    }

    @Test func followsAndUnfollowsWithoutOpeningTheApp() async throws {
        let store = Store()
        let calls = WidgetCalls()
        let writer = Self.writer(store, release: try Self.releaseStore(nil), calls: calls)
        let day = Date(timeIntervalSince1970: 1_792_917_720)
        let card = try await writer.follow(slug: "fulana", at: day)
        #expect(card == Self.fulana)
        #expect(await store.people.map(\.id) == ["fulana"])
        #expect(await store.people.first?.followedAt == day)
        try await writer.unfollow(slug: "fulana")
        #expect(await store.people.isEmpty)
        #expect(await calls.unfollowed == [nil, "fulana"])
    }

    @Test func followingAndUnfollowingAskForTheDevicePasscode() {
        #expect(FollowPersonIntent.authenticationPolicy == .requiresAuthentication)
        #expect(UnfollowPersonIntent.authenticationPolicy == .requiresAuthentication)
    }

    @Test func refusesAPersonOutsideTheIndex() async throws {
        let store = Store()
        let writer = Self.writer(store, release: try Self.releaseStore(nil), index: [])
        await #expect(throws: IntegrationError.self) {
            try await writer.follow(slug: "fulana")
        }
        #expect(await store.people.isEmpty)
    }

    @Test func refusesWhileAnUpdateIsRequired() async throws {
        let store = Store()
        try await store.follow(Self.fulana, at: .distantPast)
        let writer = Self.writer(store, release: try Self.releaseStore(.required))
        await #expect(throws: UpdateRequiredError.self) {
            try await writer.follow(slug: "fulana")
        }
        await #expect(throws: UpdateRequiredError.self) {
            try await writer.unfollow(slug: "fulana")
        }
        #expect(await store.people.map(\.id) == ["fulana"])
    }

    @MainActor
    @Test func theLiveWriterAndTheTabLinkRefuseWhileAnUpdateIsRequired() throws {
        let blocked = try Self.releaseStore(.required)
        #expect(throws: UpdateRequiredError.self) { try FollowIntentWriter.live(store: blocked) }
        #expect(throws: UpdateRequiredError.self) { try IntentWorkspace.ensureOpen(store: blocked) }
        #expect(IntegrationLink.following == URL(string: "fiscal://following"))
    }
}
