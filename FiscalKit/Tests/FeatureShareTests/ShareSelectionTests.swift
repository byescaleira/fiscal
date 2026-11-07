import FiscalDomain
import Foundation
import Testing

@testable import FeatureShare

struct ShareSelectionTests {
    private let link = URL(fileURLWithPath: "/")
    private let face = ShareFace(slug: "ana", name: "Ana Souza", party: "PSD", detail: "SP")

    private func content(_ body: ShareCardContent.Body) -> ShareCardContent {
        ShareCardContent(
            eyebrow: "EYEBROW", headline: nil, faces: [face], body: body,
            source: "Source: Chamber · updated 30/10, 14:00", stamp: "CAMARA·PER·ANA·2026-10-30",
            link: link)
    }

    private var person: ShareCardContent {
        content(
            .person([
                ShareMetric(label: "Attendance", value: "92%"),
                ShareMetric(label: "Roll-call votes", value: "537"),
                ShareMetric(label: "Bills filed", value: "87"),
                ShareMetric(label: "Office allowance used", value: "R$ 1 mi"),
            ]))
    }

    @Test func hidesOnlyOptionalFacts() throws {
        var selection = ShareSelection()
        let facts = person.optionalFacts + [.code]
        #expect(facts.count == 5)
        #expect(facts.allSatisfy { $0.isOptional })
        selection.toggle(try #require(facts.first { $0.title == "Attendance" }), among: facts)
        selection.toggle(.code, among: facts)
        #expect(!selection.showsCode)

        let shown = person.applying(selection)
        guard case .person(let metrics) = shown.body else {
            Issue.record("The body changed")
            return
        }
        #expect(
            metrics.map(\.label) == ["Roll-call votes", "Bills filed", "Office allowance used"])
        #expect(shown.source == person.source)
        #expect(shown.stamp == person.stamp)
        #expect(shown.link == person.link)

        let card = ShareCard(
            content: shown, artwork: nil, format: .stories, showsCode: selection.showsCode)
        #expect(!card.showsCode)
        #expect(!card.texts.contains("Attendance"))
        #expect(card.texts.contains(card.brand))
        #expect(card.texts.contains(shown.source))
        #expect(!facts.contains { [card.brand, shown.source, shown.stamp].contains($0.title) })
    }

    @Test func keepsTheLastFigureOn() {
        let facts = person.optionalFacts
        var selection = ShareSelection()
        for fact in facts { selection.toggle(fact, among: facts) }
        #expect(facts.filter(selection.isOn).count == 1)
        #expect(!selection.canToggle(facts[3], among: facts))
        selection.toggle(facts[0], among: facts)
        #expect(selection.isOn(facts[0]))
    }

    @Test func eachSubjectOffersItsOwnFacts() {
        let spending = ShareSpending(
            total: "R$ 10", caption: "Spending", receipts: "Receipts: 2",
            categories: [.init(name: "Rent", value: "R$ 8", share: 0.8)])
        let expenses = content(.expenses(spending))
        #expect(expenses.optionalFacts == [.largestCategory])
        var selection = ShareSelection()
        selection.toggle(.largestCategory, among: expenses.optionalFacts)
        #expect(SharePoster(expenses).facts.count == 1)
        #expect(SharePoster(expenses.applying(selection)).facts.isEmpty)

        let highlight = content(
            .highlight(
                ShareHighlight(
                    title: "Title", person: nil, place: "Senate", tally: nil, weight: "High",
                    uncertainty: nil)))
        #expect(highlight.optionalFacts == [.weight])
        var quiet = ShareSelection()
        quiet.toggle(.weight, among: highlight.optionalFacts)
        #expect(SharePoster(highlight).note == "High")
        #expect(SharePoster(highlight.applying(quiet)).note == nil)

        let compare = content(
            .compare([
                ShareCompareRow(label: "Attendance", values: ["90%", "80%"]),
                ShareCompareRow(label: "Votes", values: ["1", "2"]),
            ]))
        #expect(compare.optionalFacts.map(\.title) == ["Attendance", "Votes"])
        #expect(content(.following([face])).optionalFacts.isEmpty)
    }
}
