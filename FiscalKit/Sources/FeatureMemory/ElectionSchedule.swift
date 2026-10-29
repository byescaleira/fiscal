import FiscalDomain
import Foundation

struct ScheduledRound: Hashable, Identifiable, Sendable {
    enum Status: Sendable {
        case past, today, upcoming
    }

    let number: Int
    let day: CalendarDay
    let status: Status

    var id: Int { number }

    var title: String { String(appLocalized: "Round \(number)") }

    var shortDate: String {
        day.date().formatted(.dateTime.day().month(.abbreviated).locale(.app))
    }

    var statusText: String {
        switch status {
        case .past: String(appLocalized: "Done")
        case .today: String(appLocalized: "Today")
        case .upcoming: String(appLocalized: "Upcoming")
        }
    }
}

struct ScheduledElection: Hashable, Identifiable, Sendable {
    let year: Int
    let rounds: [ScheduledRound]
    let isCurrent: Bool

    var id: Int { year }

    var title: String { String(appLocalized: "General election \(String(year))") }

    var liveRound: ScheduledRound? { rounds.first { $0.status == .today } }

    var isFinished: Bool { rounds.allSatisfy { $0.status == .past } }
}

enum ElectionSchedule {
    private static let schedule: [(year: Int, rounds: [(month: Int, day: Int)])] = [
        (2_026, [(10, 4), (10, 25)]),
        (2_022, [(10, 2), (10, 30)]),
        (2_018, [(10, 7), (10, 28)]),
    ]

    static func elections(now: Date, calendar: Calendar = GregorianCalendar.current)
        -> [ScheduledElection]
    {
        let today = CalendarDay(now, calendar: calendar)
        return schedule.map { entry in
            ScheduledElection(
                year: entry.year,
                rounds: entry.rounds.enumerated().compactMap { index, date in
                    CalendarDay(year: entry.year, month: date.month, day: date.day).map { day in
                        ScheduledRound(
                            number: index + 1, day: day,
                            status: day < today ? .past : day == today ? .today : .upcoming)
                    }
                },
                isCurrent: entry.year == today.year)
        }
    }
}
