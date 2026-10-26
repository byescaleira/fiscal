import FiscalDomain
import Foundation
import Testing

struct VoteSummaryRelatedTests {
    private func decode(_ extra: String) throws -> VoteSummary {
        let json =
            #"{ "id": "camara-2576389-4", "house": "camara", "date": "2026-10-21", "time": "16:40", "proposition": "PL 1873/2026", "kind": "PL", "summary": "Aprovado o texto-base.", "plainSummary": null, "themes": [], "result": "Aprovada", "approved": true, "nominal": true, "yes": 412, "no": 61, "others": 9\#(extra) }"#
        return try PublicDataCoding.decoder().decode(VoteSummary.self, from: Data(json.utf8))
    }

    @Test func readsTheGroupAndTheOtherVotesOfTheDay() throws {
        let vote = try decode(
            #", "group": "camara-pl-1873-2026-2026-10-21", "relatedCount": 2, "related": [{ "id": "camara-2576389-3", "time": "15:10", "summary": "Rejeitado o requerimento de adiamento.", "nominal": false, "approved": false }, { "id": "camara-2576389-5", "time": null, "summary": "Aprovada a redação final.", "nominal": true, "approved": null }]"#
        )
        #expect(vote.group == "camara-pl-1873-2026-2026-10-21")
        #expect(vote.relatedCount == 2)
        #expect(vote.sameDayVotes.map(\.id) == ["camara-2576389-3", "camara-2576389-5"])
        #expect(vote.sameDayVotes.first?.nominal == false)
        #expect(vote.sameDayVotes.first?.approved == false)
        #expect(vote.sameDayVotes.last?.time == nil)
        #expect(vote.sameDayVotes.last?.approved == nil)
        #expect(vote.sameDayCount == 2)
    }

    @Test func countsVotesBeyondTheListedOnes() throws {
        let vote = try decode(
            #", "relatedCount": 7, "related": [{ "id": "camara-2576389-3", "time": "15:10", "summary": "Requerimento.", "nominal": false, "approved": true }]"#
        )
        #expect(vote.sameDayVotes.count == 1)
        #expect(vote.sameDayCount == 7)
    }

    @Test func neverCountsFewerThanTheListedVotes() throws {
        let vote = try decode(
            #", "relatedCount": 0, "related": [{ "id": "camara-2576389-3", "time": null, "summary": "Requerimento.", "nominal": false, "approved": null }]"#
        )
        #expect(vote.sameDayCount == 1)
    }

    @Test func aVoteWithoutRelatedFieldsHasNoneThatDay() throws {
        let vote = try decode("")
        #expect(vote.group == nil)
        #expect(vote.relatedCount == nil)
        #expect(vote.related == nil)
        #expect(vote.sameDayVotes.isEmpty)
        #expect(vote.sameDayCount == 0)
        let nulls = try decode(#", "group": null, "relatedCount": null, "related": null"#)
        #expect(nulls.sameDayCount == 0)
    }

    @Test func theInitializerDerivesTheCountFromTheList() throws {
        let day = try #require(CalendarDay("2026-10-21"))
        let related = [
            VoteSummary.Related(
                id: "senado-1", time: nil, summary: "Emenda.", nominal: false, approved: true)
        ]
        let vote = VoteSummary(
            id: "senado-2", house: .senado, date: day, time: nil, proposition: "PL 1/2026",
            kind: nil, summary: "Texto.", plainSummary: nil, themes: [], result: nil,
            approved: nil, nominal: false, tally: VoteSummary.Tally(yes: nil, no: nil, others: nil),
            related: related)
        #expect(vote.relatedCount == 1)
        #expect(vote.sameDayCount == 1)
        let empty = VoteSummary(
            id: "senado-3", house: .senado, date: day, time: nil, proposition: "PL 1/2026",
            kind: nil, summary: "Texto.", plainSummary: nil, themes: [], result: nil,
            approved: nil, nominal: false, tally: VoteSummary.Tally(yes: nil, no: nil, others: nil))
        #expect(empty.related == nil)
        #expect(empty.relatedCount == nil)
    }
}
