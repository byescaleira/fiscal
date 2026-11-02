import FeatureCore
import FiscalData
import FiscalDomain
import Foundation
import Testing

@testable import FeatureToday

@MainActor
struct FeedModelTests {
    private let now = Date(timeIntervalSince1970: 1_792_917_720)

    private func makeModel(
        following slugs: [String] = [], scenario: PublicDataScenario = .normal
    ) async throws -> FeedModel {
        let service = ShowcasePublicData(scenario: scenario, now: now)
        let repository = try FiscalDatabase.open(inMemory: true).repositories.follows
        let people = try await ShowcasePublicData(scenario: .normal, now: now).people()
        for slug in slugs {
            let card = try #require(people.first { $0.slug == slug })
            try await repository.follow(card, at: now)
        }
        return FeedModel(
            service: service, follows: repository,
            seen: FollowingSeenStore(suiteName: "feed-\(UUID().uuidString)"),
            regionUF: { nil }, now: { now })
    }

    @Test func withoutFollowingThereAreRelevantLinesAndTheEnd() async throws {
        let model = try await makeModel()
        await model.load()
        #expect(model.phase == .loaded)
        #expect(!model.items.isEmpty)
        #expect(model.followsNobody)
        #expect(model.items.allSatisfy { !$0.isFollowing })
        #expect(model.reachedEnd)
        #expect(model.endMessage.isEmpty == false)
    }

    @Test func followingBringsTheirFactsWithTheReason() async throws {
        let model = try await makeModel(following: ["tabata-amaral"])
        await model.load()
        #expect(model.items.contains { $0.isFollowing })
        model.filter = .following
        #expect(model.visible.allSatisfy { $0.isFollowing })
        model.filter = .relevant
        #expect(model.visible.allSatisfy { !$0.isFollowing })
    }

    @Test func theListIsSortedByDate() async throws {
        let model = try await makeModel(following: ["tabata-amaral"])
        await model.load()
        let dates = model.items.map(\.date)
        #expect(dates == dates.sorted(by: >))
    }

    @Test func loadingMoreAddsOlderYearsWithoutRepeatingAndEnds() async throws {
        let model = try await makeModel(following: ["tabata-amaral"])
        await model.load()
        let first = model.items.map(\.id)
        #expect(!model.reachedEnd)
        var turns = 0
        while !model.reachedEnd, turns < 40 {
            await model.loadMore()
            turns += 1
        }
        #expect(model.reachedEnd)
        let ids = model.items.map(\.id)
        #expect(Set(ids).count == ids.count)
        #expect(Set(first).isSubset(of: Set(ids)))
    }

    @Test func theListShowsOnePageAtATime() async throws {
        let model = try await makeModel(following: ["tabata-amaral"])
        await model.load()
        try #require(model.items.count > FeedModel.pageSize)
        #expect(model.visible.map(\.id) == model.items.prefix(FeedModel.pageSize).map(\.id))
        let total = model.items.count
        await model.loadMore()
        #expect(model.items.count == total)
        #expect(model.visible.count == min(total, FeedModel.pageSize * 2))
        #expect(!model.isAtEnd)
        model.filter = .following
        model.filter = .all
        #expect(model.visible.count == FeedModel.pageSize)
    }

    @Test func theEndOnlyShowsWhenNothingIsHidden() async throws {
        let model = try await makeModel(following: ["tabata-amaral"])
        await model.load()
        var turns = 0
        while !model.isAtEnd, turns < 40 {
            await model.loadMore()
            turns += 1
        }
        #expect(model.isAtEnd)
        #expect(model.reachedEnd)
        #expect(model.visible.count == model.items.count)
    }

    @Test func theRelevantFilterReadsNoOlderYear() async throws {
        let model = try await makeModel(following: ["tabata-amaral"])
        await model.load()
        let total = model.items.count
        model.filter = .relevant
        var turns = 0
        while !model.isAtEnd, turns < 40 {
            await model.loadMore()
            turns += 1
        }
        #expect(model.isAtEnd)
        #expect(!model.reachedEnd)
        #expect(model.items.count == total)
        #expect(model.endMessage.isEmpty == false)
    }

    @Test func aFailureEverywhereReachesTheScreen() async throws {
        let model = try await makeModel(scenario: .unavailable)
        await model.load()
        guard case .failed = model.phase else {
            Issue.record("The failure must reach the screen")
            return
        }
        #expect(model.isEmpty)
    }

    @Test func seeingClearsTheBadge() async throws {
        let model = try await makeModel(following: ["tabata-amaral"])
        await model.load()
        model.markSeen()
        #expect(model.newCount == 0)
    }

    @Test func emptyFilterExplainsWhy() async throws {
        let model = try await makeModel()
        await model.load()
        model.filter = .following
        #expect(model.visible.isEmpty)
        #expect(model.emptyMessage.isEmpty == false)
    }
}
