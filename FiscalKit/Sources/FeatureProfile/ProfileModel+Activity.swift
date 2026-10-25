import FeatureCore
import FiscalDomain
import Foundation

extension ProfileModel {
    public static let recentLimit = 5

    public struct MonthBar: Identifiable, Equatable {
        public let month: Int
        public let label: String
        public let cents: Int
        public let value: String

        public var id: Int { month }
    }

    public struct CategoryLine: Identifiable, Equatable {
        public let category: String
        public let value: String
        public let fraction: Double
        public let count: Int

        public var id: String { category }
    }

    public var recentVotes: [PersonVote] {
        Array((votes?.items ?? []).sorted { $0.date > $1.date }.prefix(Self.recentLimit))
    }

    public var lastVote: PersonVote? { recentVotes.first }

    public var lastVoteText: String? {
        guard let vote = lastVote else { return nil }
        return String(
            appLocalized: "Last vote · \(vote.proposition) · \(shortDay(vote.date))")
    }

    public func ballot(_ vote: PersonVote) -> ProfileBallot { ProfileBallot(vote.vote) }

    public func shortDay(_ day: CalendarDay) -> String {
        String(format: "%02d/%02d", day.day, day.month)
    }

    public func guidanceText(_ vote: PersonVote) -> String? {
        vote.partyGuidance.map {
            String(appLocalized: "Party guidance: \(ProfileBallot($0).title)")
        }
    }

    public func voteAccessibility(_ vote: PersonVote) -> String {
        let parts = [
            SourceFootnote.day(vote.date), vote.proposition, vote.summary,
            String(appLocalized: "Voted \(ballot(vote).title)"), guidanceText(vote),
        ]
        return parts.compactMap(\.self).joined(separator: ", ")
    }

    public var votesTotalText: String? {
        guard let votes else { return nil }
        return String(
            appLocalized: "Recorded votes in \(String(year)): \(PublicFormat.number(votes.total))")
    }

    public var recentProposals: [Proposal] {
        Array(
            (proposals?.items ?? []).sorted { ($0.year, $0.number) > ($1.year, $1.number) }
                .prefix(Self.recentLimit))
    }

    public var proposalsTotalText: String? {
        guard let proposals else { return nil }
        return String(
            appLocalized: "Proposals in \(String(year)): \(PublicFormat.number(proposals.total))")
    }

    public var plainSummaryNote: String {
        String(
            appLocalized:
                "The plain summary is Fiscal's rewrite. The official summary is always one tap away."
        )
    }

    public func proposalStatus(_ proposal: Proposal) -> String? {
        switch proposal.canBecomeLaw {
        case true?: String(appLocalized: "Can become law")
        case false?: String(appLocalized: "Doesn't become law")
        case nil: nil
        }
    }

    public var recentSpeeches: [Speech] {
        Array((speeches?.items ?? []).sorted { $0.date > $1.date }.prefix(3))
    }

    public var speechesTotalText: String? {
        guard let speeches else { return nil }
        return String(
            appLocalized: "Speeches in \(String(year)): \(PublicFormat.number(speeches.total))")
    }

    public var hasExpenses: Bool { !(expenses?.items.isEmpty ?? true) }

    public var expensesTotal: String { PublicFormat.money(cents: expenses?.totalCents) }

    public var monthBars: [MonthBar] {
        let symbols = monthSymbols
        return (expenses?.byMonth ?? []).sorted { $0.month < $1.month }.map { total in
            MonthBar(
                month: total.month,
                label: symbols.indices.contains(total.month - 1)
                    ? symbols[total.month - 1] : String(total.month),
                cents: total.cents, value: PublicFormat.money(cents: total.cents))
        }
    }

    public var highlightedMonth: Int? { monthBars.max(by: { $0.cents < $1.cents })?.month }

    public var expenseHeadline: String? {
        guard let top = monthBars.max(by: { $0.cents < $1.cents }) else { return nil }
        let name =
            fullMonthSymbols.indices.contains(top.month - 1)
            ? fullMonthSymbols[top.month - 1] : top.label
        return String(appLocalized: "Biggest month in \(String(year)): \(name), \(top.value)")
    }

    public var categoryLines: [CategoryLine] {
        guard let expenses, expenses.totalCents > 0 else { return [] }
        return expenses.byCategory.sorted { $0.cents > $1.cents }.map {
            CategoryLine(
                category: $0.category, value: PublicFormat.money(cents: $0.cents),
                fraction: Double($0.cents) / Double(expenses.totalCents), count: $0.count)
        }
    }

    public var expenseItems: [Expense] {
        (expenses?.items ?? []).sorted { ($0.month, $0.cents) > ($1.month, $1.cents) }
    }

    public func expenseDetail(_ expense: Expense) -> String {
        let month =
            fullMonthSymbols.indices.contains(expense.month - 1)
            ? fullMonthSymbols[expense.month - 1] : String(expense.month)
        return [expense.category, month, expense.document.map(Self.formattedDocument)]
            .compactMap(\.self).joined(separator: " · ")
    }

    public static func formattedDocument(_ document: String) -> String {
        let digits = Array(document.filter(\.isNumber))
        guard digits.count == 14 else { return document }
        let text = String(digits)
        func part(_ from: Int, _ to: Int) -> Substring {
            text[
                text.index(
                    text.startIndex, offsetBy: from)..<text.index(text.startIndex, offsetBy: to)]
        }
        return "\(part(0, 2)).\(part(2, 5)).\(part(5, 8))/\(part(8, 12))-\(part(12, 14))"
    }

    private var monthSymbols: [String] {
        var calendar = self.calendar
        calendar.locale = .app
        return calendar.shortStandaloneMonthSymbols
    }

    private var fullMonthSymbols: [String] {
        var calendar = self.calendar
        calendar.locale = .app
        return calendar.standaloneMonthSymbols
    }
}
