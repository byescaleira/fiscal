import FeatureCore
import FiscalDomain
import Foundation

public struct AgendaLine: Equatable, Sendable {
    public enum Status: Equatable, Sendable {
        case inSession
        case next(Date)
    }

    public let status: Status
    public let houses: [House]
    public let itemCount: Int
}

extension VotesModel {
    public var agendaHouses: [Agenda.HouseDay] {
        guard let agenda else { return [] }
        return agenda.houses.filter {
            isCurrent($0, in: agenda) && ($0.inSession || !$0.items.isEmpty)
        }
    }

    public var agendaLine: AgendaLine? {
        guard let agenda else { return nil }
        let current = agendaHouses
        let itemCount = current.reduce(0) { $0 + $1.items.count }
        let sitting = current.filter(\.inSession).map(\.house)
        if !sitting.isEmpty {
            return AgendaLine(status: .inSession, houses: sitting, itemCount: itemCount)
        }
        let now = now()
        let upcoming = agenda.houses.compactMap { day in
            day.nextSession.flatMap { $0 > now ? (day.house, $0) : nil }
        }
        guard let next = upcoming.map(\.1).min() else { return nil }
        let houses = upcoming.filter { CalendarDay($0.1) == CalendarDay(next) }.map(\.0)
        return AgendaLine(status: .next(next), houses: houses, itemCount: itemCount)
    }

    private func isCurrent(_ day: Agenda.HouseDay, in agenda: Agenda) -> Bool {
        let now = now()
        guard agenda.date >= CalendarDay(now) else { return false }
        if day.inSession { return true }
        guard let next = day.nextSession, next > now else { return false }
        return CalendarDay(next) == agenda.date
    }
}
