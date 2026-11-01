import FiscalDomain
import Foundation
import Testing

@testable import FeatureShare

struct ShareCaptionTests {
    private let link = URL(string: "https://fiscal.byescaleira.com/?person=ana-souza")
    private let face = ShareFace(slug: "ana-souza", name: "Ana Souza", party: "PSD", detail: "SP")

    private func content(source: String, name: String? = nil) throws -> ShareCardContent {
        let named = ShareFace(
            slug: face.slug, name: name ?? face.name, party: face.party, detail: face.detail)
        return ShareCardContent(
            eyebrow: "EYEBROW", headline: nil, faces: [named],
            body: .person([
                ShareMetric(label: "Attendance", value: "92%"),
                ShareMetric(label: "Bills filed", value: "87"),
            ]),
            source: source, stamp: "CAMARA·PER·ANA-SOUZA·2026-10-30·FISCAL.BYESCALEIRA.COM",
            link: try #require(link))
    }

    @Test func carriesFactSourceAndLink() throws {
        let caption = ShareCaption.make(try content(source: "Source: Chamber"))
        let lines = caption.components(separatedBy: "\n")
        #expect(lines.first == "Ana Souza (PSD): Attendance: 92%")
        #expect(lines.contains("Source: Chamber · 30/10/2026"))
        #expect(lines.last == link?.absoluteString)
        #expect(caption.count <= ShareCaption.limit)
    }

    @Test func doesNotRepeatADateTheSourceAlreadyHas() throws {
        let source = "Source: Chamber · updated 30/10, 14:00"
        let caption = ShareCaption.make(try content(source: source))
        #expect(caption.contains("\(source)\n"))
        #expect(!caption.contains("2026"))
    }

    @Test func followsTheSelection() throws {
        let card = try content(source: "Source: Chamber")
        var selection = ShareSelection()
        let attendance = try #require(card.optionalFacts.first)
        selection.toggle(attendance, among: card.optionalFacts)
        let caption = ShareCaption.make(card, selection: selection)
        #expect(!caption.contains("Attendance"))
        #expect(caption.contains("Bills filed: 87"))
    }

    @Test func staysWithinTheLimitAndKeepsTheLink() throws {
        let long = String(repeating: "Maria da Conceição ", count: 40)
        let caption = ShareCaption.make(
            try content(source: String(repeating: "Source ", count: 60), name: long))
        #expect(caption.count <= ShareCaption.limit)
        #expect(caption.hasSuffix(try #require(link?.absoluteString)))
        let short = ShareCaption.make(try content(source: "Source: Chamber", name: long))
        #expect(short.count <= ShareCaption.limit)
        #expect(short.contains("…"))
        #expect(short.contains("Source: Chamber"))
    }
}
