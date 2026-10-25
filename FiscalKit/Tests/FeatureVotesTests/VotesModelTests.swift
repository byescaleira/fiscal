import FiscalData
import FiscalDomain
import Foundation
import Testing

@testable import FeatureVotes

@MainActor
struct VotesModelTests {
    private let now = Date(timeIntervalSince1970: 1_792_917_720)

    @Test func loadsTheLatestFloorVotes() async throws {
        let model = VotesModel(service: ShowcasePublicData(scenario: .normal, now: now))
        await model.load()
        #expect(model.phase == .loaded)
        #expect(model.votes.count == 6)
        let first = try #require(model.votes.first)
        #expect(model.detail(for: first).contains(first.result ?? "?"))
    }

    @Test func noVotesIsAnHonestEmptyState() async {
        let model = VotesModel(service: ShowcasePublicData(scenario: .empty, now: now))
        await model.load()
        #expect(model.phase == .loaded)
        #expect(model.isEmpty)
    }

    @Test func theDetailCountsEveryVote() async throws {
        let showcase = ShowcasePublicData(scenario: .normal, now: now)
        let id = try #require(try await showcase.recentVotes().first?.id)
        let model = VoteDetailModel(id: id, service: showcase)
        await model.load()
        #expect(model.title == "PL 1873/2026")
        #expect(model.counts.map(\.value) == ["412", "61", "9"])
    }

    @Test func aMissingVoteSaysSo() async {
        let model = VoteDetailModel(
            id: "missing", service: ShowcasePublicData(scenario: .normal, now: now))
        await model.load()
        #expect(model.phase == .failed(.notFound))
    }
}
