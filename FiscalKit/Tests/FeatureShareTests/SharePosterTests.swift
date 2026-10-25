import FiscalDomain
import FiscalResource
import Foundation
import Testing

@testable import FeatureShare

struct SharePosterTests {
    private let face = ShareFace(slug: "ana", name: "Ana Souza", party: "PSD", detail: "SP")
    private let link = URL(fileURLWithPath: "/")

    private func content(
        _ body: ShareCardContent.Body, headline: String? = nil, faces: [ShareFace] = []
    )
        -> ShareCardContent
    {
        ShareCardContent(
            eyebrow: "EYEBROW", headline: headline, faces: faces, body: body, source: "Source",
            stamp: "STAMP", link: link)
    }

    private func metric(_ label: String, _ value: String) -> ShareMetric {
        ShareMetric(label: label, value: value)
    }

    @Test func aProfileLeadsWithOneFigureAndAtMostTwoFacts() {
        let poster = SharePoster(
            content(
                .person([
                    metric("Attendance", "98%"), metric("Votes", "537"), metric("Bills", "87"),
                    metric("Allowance", "R$ 1 mi"),
                ]), faces: [face]))
        #expect(poster.hero == .figure(value: "98%", caption: "Attendance"))
        #expect(poster.facts.map(\.value) == ["537", "87"])
        #expect(poster.person == face)
        #expect(poster.headline == nil)
    }

    @Test func aMissingLeadFigureGivesWayToTheFirstPublishedOne() {
        let poster = SharePoster(
            content(
                .person([
                    metric("Votes", PublicFormat.missing), metric("Assets", "R$ 3 mi"),
                    metric("Revenue", "R$ 2 mi"),
                ]), faces: [face]))
        #expect(poster.hero == .figure(value: "R$ 3 mi", caption: "Assets"))
        #expect(poster.facts.map(\.value) == [PublicFormat.missing, "R$ 2 mi"])
    }

    @Test func aProfileWithNothingPublishedShowsADash() {
        let poster = SharePoster(
            content(.person([metric("Votes", PublicFormat.missing)]), faces: [face]))
        #expect(poster.hero == .figure(value: PublicFormat.missing, caption: "Votes"))
        #expect(poster.facts.isEmpty)
    }

    @Test func theScoreboardKeepsEveryCount() {
        let tally = ShareTally(
            proposition: "PL 1/2026", official: nil, yes: "412", no: "61", others: "9",
            yesShare: 0.85, noShare: 0.13, othersShare: 0.02, result: "Approved", approved: true,
            quorum: "Quorum: 257")
        let poster = SharePoster(content(.vote(tally), headline: "Plain summary"))
        #expect(poster.hero == .tally(tally))
        #expect(poster.headline == "Plain summary")
        #expect(poster.note == "PL 1/2026")
        for count in ["412", "61", "9", "Approved"] {
            #expect(poster.texts.contains(count))
        }
    }

    @Test func theRaceKeepsEveryCandidateAndTheCount() {
        let candidates = (1...3).map {
            ShareRace.Candidate(
                number: "\($0)", name: "Candidate \($0)", party: "PT", percent: "\($0)0%",
                share: 0.3, votes: "100", elected: false)
        }
        let race = ShareRace(
            counted: "Counted: 80%", countedShare: 0.8, candidates: candidates, footnote: "Blank 1")
        let poster = SharePoster(content(.race(race), headline: "Mayor"))
        #expect(poster.texts.filter { $0.hasPrefix("Candidate") }.count == 3)
        #expect(poster.note?.contains("Counted: 80%") == true)
        #expect(poster.noteIsEssential)
        #expect(!poster.factsAreEssential)
    }

    @Test func everyRepresentativeGroupStays() {
        let groups = (1...5).map { ShareGroup(title: "Group \($0)", count: "\($0)", names: []) }
        let poster = SharePoster(content(.representatives(groups), headline: "São Paulo"))
        #expect(poster.hero == .place("São Paulo"))
        #expect(poster.facts.count == 5)
        #expect(poster.factsAreEssential)
    }

    @Test func aComparisonShowsTwoPeopleAndThreeRows() {
        let rows = (1...5).map { ShareCompareRow(label: "Row \($0)", values: ["1", "2"]) }
        let other = ShareFace(slug: "bia", name: "Bia Lima", party: "PT", detail: "RJ")
        let poster = SharePoster(content(.compare(rows), faces: [face, other]))
        #expect(poster.hero == .versus([face, other], Array(rows.prefix(3))))
        #expect(poster.person == nil)
    }

    @Test func spendingLeadsWithTheTotalAndTheLargestCategory() {
        let spending = ShareSpending(
            total: "R$ 386.637,50", caption: "Spending in 2026", receipts: "Receipts: 47",
            categories: [
                .init(name: "Travel", value: "R$ 70.000,00", share: 0.2),
                .init(name: "Office", value: "R$ 60.000,00", share: 0.15),
            ])
        let poster = SharePoster(content(.expenses(spending), faces: [face]))
        #expect(poster.hero == .figure(value: "R$ 386.637,50", caption: "Receipts: 47"))
        #expect(poster.facts.map(\.value) == ["R$ 70.000,00"])
        #expect(poster.facts.first?.label.contains("Travel") == true)
    }

    @Test func longFiguresShrinkToFitAndShortOnesKeepTheirSize() {
        for format in ShareFormat.allCases {
            #expect(format.figureSize(format.heroSize, for: "98%") == format.heroSize)
            let long = format.figureSize(format.heroSize, for: "R$ 386.637,50")
            #expect(long < format.heroSize)
            #expect(long * 13 * .posterFigureAdvance <= format.contentWidth + 0.001)
        }
    }

    @Test func theFieldTakesTheMostSaturatedColorOfTheCollection() throws {
        #expect(HexColor.saturation("#808080") == 0)
        #expect(HexColor.saturation("#FF0000") == 1)
        #expect(HexColor.saturation("oops") == 0)
        let catalog = try ArtCatalog.bundled()
        let work = try #require(catalog.works.first)
        let artwork = ShareArtwork(work: work, palette: ["#A99E8E", "#9FB7CE", "#9D7E58"])
        #expect(artwork.shade == "#9D7E58")
        #expect(ShareArtwork(work: work, palette: []).shade == nil)
    }

    @Test func onlyPublicDomainWorksBecomeTheBackdrop() throws {
        let catalog = try ArtCatalog.bundled()
        for work in catalog.works {
            #expect(ShareArtwork(work: work, palette: []).isBackdrop == work.isPublicDomain)
        }
        #expect(catalog.works.contains { !$0.isPublicDomain })
    }
}
