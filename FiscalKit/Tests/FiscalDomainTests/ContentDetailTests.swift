import Foundation
import Testing

@testable import FiscalDomain

struct ContentDetailTests {
    private let day = CalendarDay(Date(timeIntervalSince1970: 1_792_917_720))
    private let person = PersonCard(
        slug: "a", name: "Ana", office: .federalDeputy, uf: "sp", party: "PSD", photo: nil,
        status: .inOffice)

    private func highlight(
        kind: Highlight.Kind = .action, title: String = "Fato", subtitle: String = "PL 1/2026",
        plain: String? = nil, url: URL? = nil, stage: String? = nil
    ) -> Highlight {
        Highlight(
            id: "action-1", kind: kind, title: title, subtitle: subtitle, weight: 60,
            repercussion: nil, impact: 60, route: "a", person: person, proposition: "PL 1/2026",
            date: day, url: url, signals: .none, stage: stage, plainSummary: plain)
    }

    @Test func aProposalHighlightKeepsItsFactsAndAuthor() throws {
        let url = try #require(URL(string: "https://www.camara.leg.br/1"))
        let content = ContentDetail(
            highlight: highlight(plain: "Em palavras simples", url: url), method: nil,
            sourceLine: "Fonte: Câmara", shareHighlightID: "action-1")
        #expect(content.kind == .proposal)
        #expect(content.title == "Em palavras simples")
        #expect(content.officialSummary == "Fato")
        #expect(content.reference == "PL 1/2026")
        #expect(content.date == day)
        #expect(content.url == url)
        #expect(content.person == person)
        #expect(content.weight == 60)
        #expect(content.sourceLine == "Fonte: Câmara")
        #expect(content.shareHighlightID == "action-1")
    }

    @Test func missingFieldsStayMissing() {
        let content = ContentDetail(
            highlight: highlight(subtitle: ""), method: nil, sourceLine: "  ")
        #expect(content.title == "Fato")
        #expect(content.plainSummary == nil)
        #expect(content.officialSummary == nil)
        #expect(content.stage == nil)
        #expect(content.stageNote == nil)
        #expect(content.url == nil)
        #expect(content.sourceLine == nil)
        #expect(content.shareHighlightID == nil)
    }

    @Test func aStageWithoutAMethodIsNotGuessed() {
        let content = ContentDetail(
            highlight: highlight(stage: "plenary"), method: nil, sourceLine: nil)
        #expect(content.stage == nil)
    }

    @Test(arguments: [Highlight.Kind.money, .indicator])
    func moneyAndIndicatorsUseTheirSubtitleAsTheSummary(kind: Highlight.Kind) {
        let content = ContentDetail(
            highlight: highlight(kind: kind, subtitle: "O que o número diz"), method: nil,
            sourceLine: nil)
        #expect(content.plainSummary == "O que o número diz")
    }

    @Test func aProposalShowsThePlainTextAboveTheOfficialOne() {
        let proposal = Proposal(
            id: "1", kind: "PL", number: 12, year: 2_026, summary: "Altera a Lei 1",
            plainSummary: "Muda a regra", canBecomeLaw: true, themes: [], url: nil)
        let content = ContentDetail(
            proposal: proposal, status: "Pode virar lei", person: nil, sourceLine: nil)
        #expect(content.title == "Muda a regra")
        #expect(content.officialSummary == "Altera a Lei 1")
        #expect(content.reference == "PL 12/2026")
        #expect(content.stage == "Pode virar lei")
        #expect(content.date == nil)
        #expect(content.person == nil)
    }

    @Test func aProposalWithoutPlainTextDoesNotRepeatTheOfficialOne() {
        let proposal = Proposal(
            id: "1", kind: "PL", number: 12, year: 2_026, summary: "Altera a Lei 1",
            plainSummary: nil, canBecomeLaw: nil, themes: [], url: nil)
        let content = ContentDetail(proposal: proposal, status: nil, person: nil, sourceLine: nil)
        #expect(content.title == "Altera a Lei 1")
        #expect(content.officialSummary == nil)
    }

    @Test func aWidgetOpensTheContentOrTheVote() {
        #expect(
            IntegrationLink.highlight(id: "action-1", kind: .action, route: "a")?.absoluteString
                == "fiscal://highlight/action-1")
        #expect(
            IntegrationLink.highlight(id: "money-1", kind: .money, route: "")?.absoluteString
                == "fiscal://highlight/money-1")
        #expect(
            IntegrationLink.highlight(id: "vote-9", kind: .vote, route: "9")?.absoluteString
                == "fiscal://vote/9")
    }
}
