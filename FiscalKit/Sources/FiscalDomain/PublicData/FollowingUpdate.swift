import Foundation

public struct FollowingUpdate: Codable, Hashable, Identifiable, Sendable {
    public enum Kind: Codable, Hashable, Sendable {
        case vote(PersonVote)
        case expenses(year: Int, month: Int, cents: Int)
        case check(FactCheck)
    }

    public let person: PersonCard
    public let kind: Kind
    public let day: CalendarDay

    public init(person: PersonCard, kind: Kind, day: CalendarDay) {
        self.person = person
        self.kind = kind
        self.day = day
    }

    public var id: String {
        switch kind {
        case .vote(let vote): "\(person.slug)/vote/\(vote.voteId)"
        case .expenses(let year, let month, _): "\(person.slug)/expenses/\(year)-\(month)"
        case .check(let check): "\(person.slug)/check/\(check.id)"
        }
    }

    public func isNew(since seen: Date, calendar: Calendar = GregorianCalendar.current) -> Bool {
        day > CalendarDay(seen, calendar: calendar)
    }
}

public enum FollowingFeed {
    public static let windowDays = 30
    public static let limit = 50

    public struct Activity: Sendable {
        public let person: PersonCard
        public let votes: [PersonVote]
        public let expenses: ExpenseList?
        public let expensesYear: Int
        public let checks: [FactCheck]

        public init(
            person: PersonCard, votes: [PersonVote] = [], expenses: ExpenseList? = nil,
            expensesYear: Int, checks: [FactCheck] = []
        ) {
            self.person = person
            self.votes = votes
            self.expenses = expenses
            self.expensesYear = expensesYear
            self.checks = checks
        }
    }

    public static func build(
        _ activities: [Activity], today: CalendarDay,
        calendar: Calendar = GregorianCalendar.current
    ) -> [FollowingUpdate] {
        let start =
            calendar.date(byAdding: .day, value: -windowDays, to: today.date(in: calendar))
            .map { CalendarDay($0, calendar: calendar) } ?? today
        let updates = activities.flatMap { updates(for: $0) }
            .filter { $0.day >= start && $0.day <= today }
        return Array(updates.sorted(by: isOrderedBefore).prefix(limit))
    }

    public static func newCount(
        _ updates: [FollowingUpdate], seen: (String) -> Date?,
        calendar: Calendar = GregorianCalendar.current
    ) -> Int {
        updates.count { update in
            seen(update.person.slug).map { update.isNew(since: $0, calendar: calendar) } ?? false
        }
    }

    private static func updates(for activity: Activity) -> [FollowingUpdate] {
        let person = activity.person
        let votes = activity.votes.map {
            FollowingUpdate(person: person, kind: .vote($0), day: $0.date)
        }
        let checks = activity.checks.map {
            FollowingUpdate(person: person, kind: .check($0), day: $0.date)
        }
        let latest = activity.expenses?.byMonth.filter { $0.cents > 0 }.max { $0.month < $1.month }
        let expenses = latest.flatMap { month in
            CalendarDay(year: activity.expensesYear, month: month.month, day: 1).map {
                FollowingUpdate(
                    person: person,
                    kind: .expenses(
                        year: activity.expensesYear, month: month.month, cents: month.cents),
                    day: $0)
            }
        }
        return votes + checks + [expenses].compactMap(\.self)
    }

    private static func isOrderedBefore(_ lhs: FollowingUpdate, _ rhs: FollowingUpdate) -> Bool {
        if lhs.day != rhs.day { return lhs.day > rhs.day }
        let names = lhs.person.name.localizedStandardCompare(rhs.person.name)
        if names != .orderedSame { return names == .orderedAscending }
        return lhs.id < rhs.id
    }
}
