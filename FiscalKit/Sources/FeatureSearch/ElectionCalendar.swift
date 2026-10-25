import FiscalDomain
import Foundation

public struct ElectionRound: Hashable, Identifiable, Sendable {
    public enum Status: Sendable {
        case past, today, upcoming
    }

    public let number: Int
    public let day: CalendarDay
    public let status: Status

    public var id: Int { number }

    public var title: String { String(appLocalized: "Round \(number)") }

    public var shortDate: String {
        day.date().formatted(.dateTime.day().month(.abbreviated).locale(.app))
    }
}

public struct Election: Hashable, Identifiable, Sendable {
    public let year: Int
    public let rounds: [ElectionRound]
    public let isCurrent: Bool

    public var id: Int { year }

    public var title: String { String(appLocalized: "General election \(String(year))") }

    public var liveRound: ElectionRound? { rounds.first { $0.status == .today } }

    public var detail: String {
        rounds.map { "\($0.title) · \($0.shortDate)" }.joined(separator: "  ·  ")
    }
}

public enum ElectionCalendar {
    private static let schedule: [(year: Int, rounds: [(month: Int, day: Int)])] = [
        (2_026, [(10, 4), (10, 25)]),
        (2_022, [(10, 2), (10, 30)]),
        (2_018, [(10, 7), (10, 28)]),
    ]

    public static func elections(
        now: Date, calendar: Calendar = FiscalCalendar.current
    ) -> [Election] {
        let today = CalendarDay(now, calendar: calendar)
        return schedule.map { entry in
            Election(
                year: entry.year,
                rounds: entry.rounds.enumerated().compactMap { index, date in
                    CalendarDay(year: entry.year, month: date.month, day: date.day).map { day in
                        ElectionRound(
                            number: index + 1, day: day,
                            status: day < today ? .past : day == today ? .today : .upcoming)
                    }
                },
                isCurrent: entry.year == today.year)
        }
    }
}
