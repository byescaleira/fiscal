import FiscalDomain
import Foundation
import Testing

@testable import FeatureShare

struct ShareContentRulesTests {
    private let missing = PublicFormat.missing

    private func content(_ body: ShareCardContent.Body, source: String = "Source: Chamber")
        -> ShareCardContent
    {
        ShareCardContent(
            eyebrow: "E", headline: "H",
            faces: [ShareFace(slug: "a", name: "A", party: "PSD", detail: "SP")], body: body,
            source: source, stamp: "S", link: URL(fileURLWithPath: "/"))
    }

    private func tally(yes: String, no: String, others: String = "0", result: String? = nil)
        -> ShareTally
    {
        ShareTally(
            proposition: "PL 1/2026 · PL", official: nil, yes: yes, no: no, others: others,
            yesShare: 0, noShare: 0, othersShare: 0, result: result, approved: nil, quorum: nil)
    }

    @Test func missingMetricsLeaveAndZeroNeverLeads() throws {
        let published = try #require(
            content(
                .person([
                    ShareMetric(label: "Votes", value: "0"),
                    ShareMetric(label: "Attendance", value: missing),
                    ShareMetric(label: "Bills", value: "87"),
                ])
            ).published)
        guard case .person(let metrics) = published.body else {
            Issue.record("expected a person")
            return
        }
        #expect(metrics.map(\.label) == ["Bills", "Votes"])
        #expect(published.optionalFacts.map(\.title) == ["Bills", "Votes"])
        #expect(ShareStatement(published).figure == "87")
        #expect(!ShareCaption.make(published).contains(missing))
    }

    @Test func aPersonWithNothingHasNoCard() {
        #expect(content(.person([ShareMetric(label: "Votes", value: missing)])).published == nil)
        #expect(content(.person([ShareMetric(label: "Votes", value: "0")])).published == nil)
    }

    @Test func comparisonKeepsOnlyRowsBothSidesHave() throws {
        let published = try #require(
            content(
                .compare([
                    ShareCompareRow(label: "Assets", values: ["R$ 1 mi", missing]),
                    ShareCompareRow(label: "Bills", values: ["3", "0"]),
                    ShareCompareRow(label: "Votes", values: ["0", "0"]),
                ])
            ).published)
        guard case .compare(let rows) = published.body else {
            Issue.record("expected a comparison")
            return
        }
        #expect(rows.map(\.label) == ["Bills"])
        #expect(content(.compare([])).published == nil)
    }

    @Test func aSymbolicVoteShowsTheResultAndNoScore() throws {
        let published = try #require(
            content(.vote(tally(yes: missing, no: missing, others: missing, result: "Approved")))
                .published)
        let statement = ShareStatement(published)
        #expect(statement.figure == nil)
        #expect(statement.phrase == "PL 1/2026: Approved")
        #expect(!statement.texts.contains(missing))
        #expect(!ShareBoard(published).texts.contains(missing))
        #expect(!SharePoster(published).texts.contains(missing))
    }

    @Test func zeroOthersDoNotBecomeATile() throws {
        let statement = ShareStatement(
            try #require(content(.vote(tally(yes: "12", no: "3", result: "Approved"))).published))
        #expect(statement.rows.map(\.value) == ["Approved"])
    }

    @Test func spendingWithoutMoneyAndCountsWithoutCandidatesHaveNoCard() {
        let spending = ShareSpending(
            total: "R$ 0,00", caption: "C", receipts: "Receipts: 0", categories: [])
        #expect(content(.expenses(spending)).published == nil)
        let race = ShareRace(counted: "C", countedShare: 0, candidates: [], footnote: "F")
        #expect(content(.race(race)).published == nil)
    }

    @Test func aCardWithoutASourceIsNotPublished() {
        let metric = ShareMetric(label: "Bills", value: "87")
        #expect(content(.person([metric]), source: "Source: \(missing)").published == nil)
    }
}
