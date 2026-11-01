import FeatureCore
import FiscalData
import FiscalDomain
import Foundation
import Testing

@testable import FeatureMine

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct MineFollowingTests {
    private let now = Date(timeIntervalSince1970: 1_792_917_720)

    private func makeModel(
        code: String? = nil, follows: (any FollowRepository)?, suite: String
    ) throws -> MineModel {
        let defaults = try #require(UserDefaults(suiteName: "mine-\(UUID().uuidString)"))
        let memory = MinePlaceMemory(defaults: defaults)
        memory.code = code
        let clock = now
        return MineModel(
            service: ShowcasePublicData(scenario: .normal, now: now), follows: follows,
            memory: memory, seen: FollowingSeenStore(suiteName: suite), now: { clock },
            publishesSnapshot: false)
    }

    @Test func suggestsRepresentativesAndSupportedNotFollowed() async throws {
        let suite = "following-\(UUID().uuidString)"
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let follows = try FiscalDatabase.open(inMemory: true).repositories.follows
        let model = try makeModel(code: "sp", follows: follows, suite: suite)
        await model.load()
        let first = try #require(model.suggestions.first)
        #expect(model.suggestions.count <= MineModel.suggestionLimit)
        let ranks = model.suggestions.map { MineModel.rank($0.office) }
        #expect(ranks == ranks.sorted())
        try await follows.follow(first, at: now)
        await model.load()
        #expect(!model.suggestions.map(\.slug).contains(first.slug))
        #expect(Set(model.suggestions.map(\.slug)).count == model.suggestions.count)
    }

    @Test func buildsUpdatesAndClearsTheBadgeWhenSeen() async throws {
        let suite = "following-\(UUID().uuidString)"
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let follows = try FiscalDatabase.open(inMemory: true).repositories.follows
        let people = try await ShowcasePublicData(scenario: .normal, now: now).people()
        for card in people.prefix(3) {
            try await follows.follow(card, at: .distantPast)
        }
        let model = try makeModel(follows: follows, suite: suite)
        await model.load()
        #expect(model.updatesPhase == .loaded)
        #expect(model.updates.count <= FollowingFeed.limit)
        #expect(model.updates.map(\.day) == model.updates.map(\.day).sorted(by: >))
        #expect(model.newCount == model.updates.count)
        model.markSeen()
        #expect(model.newCount == 0)
        #expect(model.updates.allSatisfy { !model.isNew($0) })
    }

    @Test func emptiesTheFeedWhenNobodyIsFollowed() async throws {
        let suite = "following-\(UUID().uuidString)"
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let follows = try FiscalDatabase.open(inMemory: true).repositories.follows
        let model = try makeModel(follows: follows, suite: suite)
        await model.load()
        #expect(model.updates.isEmpty)
        #expect(model.updatesPhase == .idle)
        #expect(model.newCount == 0)
    }
}
