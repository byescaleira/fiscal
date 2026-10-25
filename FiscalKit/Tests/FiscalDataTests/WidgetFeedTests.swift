import FiscalDomain
import Foundation
import Testing

@testable import FiscalData

struct WidgetFeedTests {
    private let now = Date(timeIntervalSince1970: 1_792_917_720)

    private func feed(_ scenario: PublicDataScenario) -> WidgetFeed {
        WidgetFeed(service: ShowcasePublicData(scenario: scenario, now: now))
    }

    @Test func showsTheLatestVoteWithItsScore() async throws {
        let state = await feed(.normal).votes()
        let deck = try #require(state.value)
        #expect(deck.headline.hasScore)
        #expect(deck.earlier.count == VoteDeck.earlierLimit)
        let days = [deck.headline.day] + deck.earlier.map(\.day)
        #expect(days == days.sorted(by: >))
    }

    @Test func showsTheRepresentativesOfThePickedState() async throws {
        let state = await feed(.normal).representatives(uf: "3550308")
        let digest = try #require(state.value)
        #expect(digest.uf == "sp")
        #expect(digest.featured.first?.office == .governor)
        #expect(digest.featured.count <= RepresentativesDigest.featuredLimit)
        #expect(digest.featured.allSatisfy { $0.uf == "sp" })
    }

    @Test func asksForAStateBeforeLoading() async {
        #expect(await feed(.normal).representatives(uf: nil) == .needsPlace)
        #expect(await feed(.normal).representatives(uf: "xx") == .needsPlace)
    }

    @Test func reportsEmptyAndUnavailableData() async {
        #expect(await feed(.empty).votes() == .empty)
        #expect(await feed(.empty).representatives(uf: "sp") == .empty)
        #expect(await feed(.offline).votes() == .unavailable(offline: true))
        #expect(await feed(.unavailable).representatives(uf: "sp") == .unavailable(offline: false))
    }
}
