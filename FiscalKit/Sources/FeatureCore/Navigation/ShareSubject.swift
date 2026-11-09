public enum ShareSubject: Hashable, Sendable {
    case person(slug: String)
    case vote(id: String)
    case expenses(slug: String, year: Int)
    case expense(slug: String, year: Int, id: String)
    case expenseMonth(slug: String, year: Int, month: Int)
    case personVote(slug: String, year: Int, voteID: String)
    case proposal(slug: String, year: Int, id: String)
    case race(id: String)
    case compare(slugs: [String])
    case representatives(uf: String)
    case highlight(id: String)
    case investigation(InvestigationSummary)
    case following
}
