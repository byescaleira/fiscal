import CoreSpotlight
import FeatureCore
import FiscalData
import FiscalDomain
import Foundation
import Synchronization
import Testing

@testable import AppShell

private final class FakeIndex: PeopleIndexing {
    private let batches = Mutex<[[SpotlightPerson]]>([])

    var all: [[SpotlightPerson]] { batches.withLock { $0 } }

    func replace(with people: [SpotlightPerson]) async {
        batches.withLock { $0.append(people) }
    }
}

private struct FakeFollows: FollowRepository {
    let cards: [PersonCard]

    func followed() async throws -> [FollowedPerson] {
        cards.map { FollowedPerson(card: $0, followedAt: .distantPast) }
    }

    func isFollowing(slug: String) async throws -> Bool { false }
    func follow(_ card: PersonCard, at date: Date) async throws {}
    func unfollow(slug: String) async throws {}
}

@MainActor
struct IntegrationCenterTests {
    private let now = Date(timeIntervalSince1970: 1_792_917_720)

    private func center(_ defaults: UserDefaults, _ index: FakeIndex, group: String)
        -> IntegrationCenter
    {
        let service = ShowcasePublicData(scenario: .normal, now: now)
        return IntegrationCenter(
            indexer: index, defaults: defaults, place: HomePlace(suiteName: group),
            service: { service })
    }

    @Test func indexesFollowedAndOpenedProfilesWithoutTheLens() async throws {
        let suite = "fiscal.tests.center.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let index = FakeIndex()
        let center = center(defaults, index, group: suite)
        let followed = PersonCard(
            slug: "lula", name: "Lula", office: .president, uf: "br", party: "PT", photo: nil,
            status: .inOffice)
        let follows = FakeFollows(cards: [followed])
        await center.observe(
            routes: [.person(slug: "kim-kataguiri"), .vote(id: "x")], follows: follows)
        await center.observe(routes: [.person(slug: "kim-kataguiri")], follows: follows)
        #expect(index.all.count == 1)
        let entries = try #require(index.all.last)
        #expect(entries.map(\.id) == ["lula", "kim-kataguiri"])
        let lensWords = ["support", "apoio", "lens", "lente"]
        #expect(
            entries.allSatisfy { entry in
                !lensWords.contains { word in entry.keywords.contains(word) }
            })
    }

    @Test func mirrorsThePickedStateForTheWidgets() throws {
        let suite = "fiscal.tests.center.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let center = center(defaults, FakeIndex(), group: suite)
        defaults.set("2927408", forKey: HomePlace.mineKey)
        #expect(center.syncWidgets())
        #expect(HomePlace(suiteName: suite).uf == "ba")
        #expect(!center.syncWidgets())
    }

    @Test func opensProfilesFromSpotlight() {
        let activity = NSUserActivity(activityType: CSSearchableItemActionType)
        activity.userInfo = [CSSearchableItemActivityIdentifier: "tabata-amaral"]
        #expect(
            SpotlightPeopleIndex.url(from: activity)?.absoluteString
                == "fiscal://person/tabata-amaral")
        #expect(SpotlightPeopleIndex.url(from: NSUserActivity(activityType: "other")) == nil)
    }
}
