import FeatureCore
import FiscalData
import FiscalDomain
import Foundation
import Testing

@testable import FeatureVotes

@MainActor
struct VoteDetailModelPlenaryTests {
    private static func detail(
        house: House, proposition: String, nominal: Bool = true, yes: Int?, no: Int?, others: Int?
    ) -> VoteDetail {
        let summary = VoteSummary(
            id: "\(house.rawValue)-1", house: house,
            date: CalendarDay(Date(timeIntervalSince1970: 1_792_000_000)), time: nil,
            proposition: proposition, kind: nil, summary: "Texto", plainSummary: nil, themes: [],
            result: nil, approved: false, nominal: nominal,
            tally: VoteSummary.Tally(yes: yes, no: no, others: others))
        return VoteDetail(
            vote: summary, quorum: nil, guidance: [], parties: [], people: [], sources: [])
    }

    private func loaded(_ detail: VoteDetail) async -> VoteDetailModel {
        let model = VoteDetailModel(id: detail.vote.id, service: SingleVote(detail: detail))
        await model.load()
        return model
    }

    @Test func aChamberBillFillsTheFloorWithoutALine() async throws {
        let vote = await loaded(
            Self.detail(house: .camara, proposition: "PLP 281/2019", yes: 252, no: 176, others: 1))
        let plenary = try #require(vote.plenary)
        #expect(plenary.seats == 513)
        #expect(plenary.absent == 84)
        #expect(plenary.requiredYes == nil)
        #expect(vote.plenaryLayout?.count == 513)
        #expect(vote.plenaryLegend.map(\.count) == [252, 176, 1, 84])
        #expect(vote.plenaryLegend.map(\.group) == [.yes, .no, .other, .absent])
        #expect(vote.plenaryAccessibility?.contains("513") == true)
        #expect(vote.accessibilityScore.contains(vote.plenaryAccessibility ?? "—"))
    }

    @Test func anAmendmentInTheChamberDrawsTheLineAt308() async {
        let vote = await loaded(
            Self.detail(house: .camara, proposition: "PEC 9/2026", yes: 320, no: 150, others: 5))
        #expect(vote.plenary?.requiredYes == 308)
        #expect(vote.requiredYes == 308)
        #expect(vote.plenaryAccessibility?.contains("308") == true)
    }

    @Test func anAmendmentInTheSenateDrawsTheLineAt49() async {
        let vote = await loaded(
            Self.detail(house: .senado, proposition: "PEC 221/2019", yes: 75, no: 1, others: 3))
        #expect(vote.plenary?.seats == 81)
        #expect(vote.plenary?.absent == 2)
        #expect(vote.plenary?.requiredYes == 49)
    }

    @Test func aVoiceVoteAPendingVoteAndAnImpossibleTallyKeepTheBar() async {
        let voice = await loaded(
            Self.detail(
                house: .camara, proposition: "PL 1/2026", nominal: false, yes: 10, no: 2, others: 0)
        )
        let pending = await loaded(
            Self.detail(house: .camara, proposition: "PL 1/2026", yes: nil, no: nil, others: nil))
        let empty = await loaded(
            Self.detail(house: .senado, proposition: "PL 1/2026", yes: 0, no: 0, others: 0))
        let impossible = await loaded(
            Self.detail(house: .senado, proposition: "PL 1/2026", yes: 70, no: 20, others: 0))
        for vote in [voice, pending, empty, impossible] {
            #expect(vote.plenary == nil)
            #expect(vote.plenaryLegend.isEmpty)
            #expect(vote.plenaryAccessibility == nil)
        }
    }
}
