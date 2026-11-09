import FeatureCore
import FiscalData
import FiscalDomain
import Foundation
import Testing

@testable import FeatureShare

@MainActor
struct ShareItemCardsTests {
    private let now = Date(timeIntervalSince1970: 1_792_917_720)
    private let builder = ShareCardBuilder(calendar: GregorianCalendar.current)

    private var service: ShowcasePublicData { ShowcasePublicData(scenario: .normal, now: now) }

    private static func expense(id: String, document: String?, cents: Int, month: Int = 3)
        -> Expense
    {
        Expense(
            id: id, year: 2026, month: month, category: "Telefonia", supplier: "Fornecedor \(id)",
            document: document, cents: cents, url: nil)
    }

    private static let list = ExpenseList(
        items: [
            expense(id: "company", document: "11222333000181", cents: 123_400),
            expense(id: "person", document: nil, cents: 50_000),
            expense(id: "other", document: "22333444000172", cents: 29_826_600, month: 4),
        ],
        totalCents: 30_000_000,
        byMonth: [
            ExpenseList.MonthTotal(month: 3, cents: 173_400),
            ExpenseList.MonthTotal(month: 4, cents: 29_826_600),
        ],
        byCategory: [ExpenseList.CategoryTotal(category: "Telefonia", cents: 30_000_000, count: 3)]
    )

    @Test func aCompanyReceiptSaysHowMuchItIsPartOf() async throws {
        let profile = try await service.profile(slug: "tabata-amaral")
        let card = try #require(builder.expense(profile, list: Self.list, id: "company"))
        guard case .receipt(let receipt) = card.body else {
            Issue.record("Expected a receipt")
            return
        }
        #expect(receipt.supplier == "Fornecedor company")
        #expect(receipt.category == "Telefonia")
        #expect(receipt.amount == PublicFormat.money(cents: 123_400))
        #expect(receipt.context.contains("3"))
        #expect(receipt.context.contains("2026"))
        #expect(receipt.context.contains(PublicFormat.money(cents: 30_000_000)))
        #expect(card.published != nil)
        #expect(card.link.absoluteString.contains("expenses=tabata-amaral-2026"))
        #expect(card.source.contains("Câmara"))
    }

    @Test func aReceiptWithoutCompanyNumberNeverBecomesACard() async throws {
        let profile = try await service.profile(slug: "tabata-amaral")
        #expect(builder.expense(profile, list: Self.list, id: "person") == nil)
        #expect(builder.expense(profile, list: Self.list, id: "missing") == nil)
        #expect(!Self.expense(id: "cpf", document: "12345678901", cents: 1).isCompany)
        #expect(Self.expense(id: "cnpj", document: "11222333000181", cents: 1).isCompany)
    }

    @Test func aMonthShowsItsTotalAndItsCategories() async throws {
        let profile = try await service.profile(slug: "tabata-amaral")
        let card = try #require(
            builder.expenseMonth(profile, list: Self.list, year: 2026, month: 3))
        guard case .expenses(let spending) = card.body else {
            Issue.record("Expected spending")
            return
        }
        #expect(spending.total == PublicFormat.money(cents: 173_400))
        #expect(spending.categories.map(\.name) == ["Telefonia"])
        #expect(card.link.absoluteString.contains("expenses=tabata-amaral-2026"))
        #expect(builder.expenseMonth(profile, list: Self.list, year: 2026, month: 9) == nil)
    }

    @Test func aPersonVoteCarriesTheProposalAndNoJudgement() async throws {
        let profile = try await service.profile(slug: "tabata-amaral")
        let votes = try await service.votes(slug: "tabata-amaral", year: 2026)
        let vote = try #require(votes.items.first)
        let card = builder.personVote(profile, vote: vote)
        guard case .ballot(let ballot) = card.body else {
            Issue.record("Expected a ballot")
            return
        }
        #expect(ballot.proposition == vote.heading)
        #expect(ballot.summary == vote.summary)
        #expect(ballot.vote == vote.vote)
        #expect(card.faces.map(\.slug) == ["tabata-amaral"])
        #expect(card.link.absoluteString.contains("vote=\(vote.voteId)"))
        #expect(card.published != nil)
    }

    @Test func aProposalLinksToThePersonAndShowsOnlyTheYear() async throws {
        let profile = try await service.profile(slug: "tabata-amaral")
        let proposals = try await service.proposals(slug: "tabata-amaral", year: 2026)
        let proposal = try #require(proposals.items.first)
        let card = builder.proposal(profile, proposal: proposal)
        guard case .proposal(let item) = card.body else {
            Issue.record("Expected a proposal")
            return
        }
        #expect(item.reference == proposal.reference)
        #expect(card.link.absoluteString.contains("person=tabata-amaral"))
        #expect(card.eyebrow.contains("2026"))
    }

    @Test func aCardWithoutItsMainFactOrSourceDoesNotExist() {
        let make = { (body: ShareCardContent.Body, source: String) in
            ShareCardContent(
                eyebrow: "E", headline: nil, faces: [], body: body, source: source, stamp: "S",
                link: URL(fileURLWithPath: "/"))
        }
        let receipt = ShareReceipt(
            supplier: "A", category: "B", amount: PublicFormat.missing, period: "C", context: "D")
        #expect(make(.receipt(receipt), "Fonte").published == nil)
        let ballot = ShareBallot(
            proposition: "", summary: "A", vote: "Sim", date: "01/01/2026", result: nil)
        #expect(make(.ballot(ballot), "Fonte").published == nil)
        let proposal = ShareProposal(reference: "PL 1/2026", summary: "")
        #expect(make(.proposal(proposal), "Fonte").published == nil)
        let whole = ShareProposal(reference: "PL 1/2026", summary: "Resumo")
        #expect(make(.proposal(whole), "Fonte").published != nil)
        #expect(make(.proposal(whole), "Fonte: \(PublicFormat.missing)").published == nil)
    }

    @Test func everyItemLoadsThroughTheModelWithoutTheDuel() async throws {
        let list = try await service.expenses(slug: "tabata-amaral", year: 2026)
        let company = try #require(list.items.first { $0.isCompany })
        let votes = try await service.votes(slug: "tabata-amaral", year: 2026)
        let vote = try #require(votes.items.first)
        let proposals = try await service.proposals(slug: "tabata-amaral", year: 2026)
        let proposal = try #require(proposals.items.first)
        let subjects: [ShareSubject] = [
            .expense(slug: "tabata-amaral", year: 2026, id: company.id),
            .expenseMonth(slug: "tabata-amaral", year: 2026, month: company.month),
            .personVote(slug: "tabata-amaral", year: 2026, voteID: vote.voteId),
            .proposal(slug: "tabata-amaral", year: 2026, id: proposal.id),
        ]
        for subject in subjects {
            let model = ShareModel(subject: subject, service: service)
            await model.load()
            let content = try #require(model.content)
            #expect(model.style == .typographic)
            #expect(content.styles == [.typographic, .data, .poster])
            #expect(!ShareCaption.make(content).isEmpty)
            #expect(!ShareStatement(content).texts.isEmpty)
        }
    }

    @Test func aPersonReceiptSubjectFailsInsteadOfShowingTheName() async throws {
        let list = try await service.expenses(slug: "tabata-amaral", year: 2026)
        let individual = try #require(list.items.first { !$0.isCompany })
        let model = ShareModel(
            subject: .expense(slug: "tabata-amaral", year: 2026, id: individual.id),
            service: service)
        await model.load()
        #expect(model.content == nil)
        #expect(model.phase == .failed(.notFound))
    }
}
