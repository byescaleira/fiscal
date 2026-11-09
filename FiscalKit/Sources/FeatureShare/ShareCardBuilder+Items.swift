import FiscalDomain
import Foundation

public struct ShareReceipt: Hashable, Sendable {
    public let supplier: String
    public let category: String
    public let amount: String
    public let period: String
    public let context: String
}

public struct ShareBallot: Hashable, Sendable {
    public let proposition: String
    public let summary: String
    public let vote: String
    public let date: String
    public let result: String?
}

public struct ShareProposal: Hashable, Sendable {
    public let reference: String
    public let summary: String
}

extension ShareCardBuilder {
    public func expense(_ profile: Profile, list: ExpenseList, id: String) -> ShareCardContent? {
        guard let expense = list.items.first(where: { $0.id == id }), expense.isCompany else {
            return nil
        }
        let source = primarySource(profile.sources, for: profile.office)
        let year = String(expense.year)
        let receipt = ShareReceipt(
            supplier: expense.supplier, category: expense.category,
            amount: PublicFormat.money(cents: expense.cents),
            period: period(month: expense.month, year: expense.year),
            context: String(
                appLocalized:
                    "One of \(list.items.count) receipts from \(year), total \(PublicFormat.money(cents: list.totalCents))"
            ))
        return ShareCardContent(
            eyebrow: eyebrow(String(appLocalized: "Office allowance"), year),
            headline: nil, faces: [face(profile)], body: .receipt(receipt),
            source: sourceLine(source),
            stamp: stamp(source, "NOT", expense.id, source?.updatedAt),
            link: link("expenses", "\(profile.slug)-\(expense.year)"))
    }

    public func expenseMonth(
        _ profile: Profile, list: ExpenseList, year: Int, month: Int
    ) -> ShareCardContent? {
        let items = list.items.filter { $0.month == month }
        guard !items.isEmpty else { return nil }
        let source = primarySource(profile.sources, for: profile.office)
        let categories = Dictionary(grouping: items, by: \.category).map { category, expenses in
            ExpenseList.CategoryTotal(
                category: category, cents: expenses.map(\.cents).reduce(0, +),
                count: expenses.count)
        }
        let total = items.map(\.cents).reduce(0, +)
        let monthList = ExpenseList(
            items: items, totalCents: total,
            byMonth: [ExpenseList.MonthTotal(month: month, cents: total)],
            byCategory: categories)
        let label = period(month: month, year: year)
        return ShareCardContent(
            eyebrow: eyebrow(String(appLocalized: "Office allowance"), label),
            headline: nil, faces: [face(profile)],
            body: .expenses(spending(monthList, period: label)), source: sourceLine(source),
            stamp: stamp(source, "GAS", "\(profile.slug)-\(year)-\(month)", source?.updatedAt),
            link: link("expenses", "\(profile.slug)-\(year)"))
    }

    public func personVote(_ profile: Profile, vote: PersonVote) -> ShareCardContent {
        let source = primarySource(profile.sources, for: profile.office)
        let result: String? =
            switch vote.approved {
            case true?: String(appLocalized: "Approved")
            case false?: String(appLocalized: "Rejected")
            case nil: nil
            }
        let ballot = ShareBallot(
            proposition: vote.heading, summary: vote.summary, vote: vote.vote,
            date: fullDate(vote.date), result: result)
        return ShareCardContent(
            eyebrow: eyebrow(String(appLocalized: "Floor vote"), dayMonth(vote.date)),
            headline: nil, faces: [face(profile)], body: .ballot(ballot),
            source: sourceLine(source),
            stamp: stamp(source, "VOT", vote.voteId, vote.date.date(in: calendar)),
            link: link("vote", vote.voteId))
    }

    public func proposal(_ profile: Profile, proposal: Proposal) -> ShareCardContent {
        let source = primarySource(profile.sources, for: profile.office)
        let item = ShareProposal(
            reference: proposal.reference, summary: proposal.plainSummary ?? proposal.summary)
        return ShareCardContent(
            eyebrow: eyebrow(String(appLocalized: "Proposal"), String(proposal.year)),
            headline: nil, faces: [face(profile)], body: .proposal(item),
            source: sourceLine(source),
            stamp: stamp(source, "PRO", proposal.id, source?.updatedAt),
            link: link("person", profile.slug))
    }

    private func period(month: Int, year: Int) -> String {
        guard let day = CalendarDay(year: year, month: month, day: 1) else { return String(year) }
        return day.date(in: calendar).formatted(Date.FormatStyle(locale: .app).month(.wide).year())
    }
}
