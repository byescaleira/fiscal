import FeatureCore
import FiscalDomain
import Foundation
import Testing

@testable import FeatureVotes

@MainActor
struct VoteSameDaySectionTests {
    private static let base = String(
        appLocalized:
            "The Chamber and the Senate often vote on the same bill several times in one day: requests, amendments, the main text and the final wording. The lists show the vote on the text."
    )

    private static let related = [
        VoteSummary.Related(
            id: "camara-2", time: "15:10", summary: "Requerimento de adiamento.", nominal: false,
            approved: false),
        VoteSummary.Related(
            id: "camara-3", time: nil, summary: "Redação final.", nominal: true, approved: true),
    ]

    private func loaded(related: [VoteSummary.Related], count: Int? = nil) async throws
        -> VoteDetailModel
    {
        let summary = VoteSummary(
            id: "camara-1", house: .camara, date: try #require(CalendarDay("2026-10-21")),
            time: "16:40", proposition: "PL 1/2026", kind: nil, summary: "Texto-base.",
            plainSummary: nil, themes: [], result: nil, approved: true, nominal: true,
            tally: VoteSummary.Tally(yes: 300, no: 100, others: 0), related: related,
            relatedCount: count)
        let detail = VoteDetail(
            vote: summary, quorum: nil, guidance: [], parties: [], people: [], sources: [])
        let model = VoteDetailModel(id: "camara-1", service: SingleVote(detail: detail))
        await model.load()
        return model
    }

    @Test func listsTheOtherVotesWithTheirTimeAndKind() async throws {
        let vote = try await loaded(related: Self.related)
        #expect(vote.sameDayVotes.map(\.id) == ["camara-2", "camara-3"])
        let voice = String(appLocalized: "Voice vote")
        let rollCall = String(appLocalized: "Roll-call vote")
        #expect(vote.sameDayLine(Self.related[0]) == "15:10 · \(voice)")
        #expect(vote.sameDayLine(Self.related[1]) == rollCall)
    }

    @Test func theFooterExplainsWithoutHiddenVotes() async throws {
        let vote = try await loaded(related: Self.related)
        #expect(vote.sameDayFooter == Self.base)
    }

    @Test func theFooterCountsTheHiddenVotes() async throws {
        let vote = try await loaded(related: Self.related, count: 5)
        let hidden = String(appLocalized: "\(3) more aren't listed here.")
        #expect(vote.sameDayFooter == "\(Self.base) \(hidden)")
    }

    @Test func noVoteMeansNoSection() async throws {
        let empty = VoteDetailModel(id: "camara-1", service: nil)
        #expect(empty.sameDayVotes.isEmpty)
        #expect(empty.sameDayFooter == Self.base)
        let vote = try await loaded(related: [])
        #expect(vote.sameDayVotes.isEmpty)
    }
}
