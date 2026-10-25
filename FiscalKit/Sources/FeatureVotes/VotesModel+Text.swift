import FeatureCore
import FiscalDomain
import Foundation

extension VotesModel {
    public func dayNumber(_ day: Day) -> String {
        day.id.date().formatted(Date.FormatStyle(locale: .app).day(.defaultDigits))
    }

    public func dayTitle(_ day: Day) -> String {
        let calendar = FiscalCalendar.current
        let date = day.id.date(in: calendar)
        let today = CalendarDay(now(), calendar: calendar)
        if day.id == today { return String(appLocalized: "Today") }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today.date(in: calendar)),
            day.id == CalendarDay(yesterday, calendar: calendar)
        {
            return String(appLocalized: "Yesterday")
        }
        return date.formatted(Date.FormatStyle(locale: .app).weekday(.wide)).capitalized(
            with: .app)
    }

    public func dayMonth(_ day: Day) -> String {
        day.id.date().formatted(Date.FormatStyle(locale: .app).month(.wide))
    }

    public func dayAccessibility(_ day: Day) -> String {
        let date = day.id.date().formatted(
            Date.FormatStyle(locale: .app).weekday(.wide).day().month(.wide))
        return "\(dayTitle(day)), \(date)"
    }

    public func houseLine(_ vote: VoteSummary) -> String {
        let house = Self.shortHouse(vote.house).uppercased(with: .app)
        return [house, vote.time].compactMap(\.self).joined(separator: " · ")
    }

    public func summary(_ vote: VoteSummary) -> String { vote.plainSummary ?? vote.summary }

    public func yesText(_ vote: VoteSummary) -> String { PublicFormat.number(vote.yes) }

    public func noText(_ vote: VoteSummary) -> String { PublicFormat.number(vote.no) }

    public func othersText(_ vote: VoteSummary) -> String {
        String(appLocalized: "\(PublicFormat.number(vote.others)) other")
    }

    public func accessibility(_ vote: VoteSummary) -> String {
        [
            vote.proposition, summary(vote), VoteOutcome(vote).title,
            VoteTally.label(vote.tally), vote.house.title, vote.time,
        ]
        .compactMap(\.self).joined(separator: ". ")
    }

    public func sourceText(_ day: Day) -> String {
        let houses = House.allCases.filter { house in day.votes.contains { $0.house == house } }
        let names = houses.map(\.title).formatted(.list(type: .and).locale(.app))
        let date = day.id.date().formatted(
            Date.FormatStyle(locale: .app).day(.twoDigits).month(.twoDigits))
        return String(appLocalized: "Source: \(names) · votes of \(date)")
    }

    public var agendaTitle: String {
        guard let agenda, !isAgendaToday else { return String(appLocalized: "Today's Agenda") }
        let date = agenda.date.date().formatted(
            Date.FormatStyle(locale: .app).day(.twoDigits).month(.twoDigits))
        return String(appLocalized: "Agenda for \(date)")
    }

    public var agendaDayNumber: String {
        (agenda?.date.date() ?? now()).formatted(
            Date.FormatStyle(locale: .app).day(.defaultDigits))
    }

    public var agendaWeekday: String {
        (agenda?.date.date() ?? now()).formatted(Date.FormatStyle(locale: .app).weekday(.wide))
            .capitalized(with: .app)
    }

    public func agendaStatus(_ day: Agenda.HouseDay) -> String {
        if day.inSession { return String(appLocalized: "In session now") }
        guard let next = day.nextSession else {
            return String(appLocalized: "No session scheduled")
        }
        let text = next.formatted(
            Date.FormatStyle(locale: .app).weekday(.abbreviated).day(.twoDigits).month(.twoDigits)
                .hour().minute())
        return String(appLocalized: "Next session: \(text)")
    }

    public var agendaSource: String {
        String(appLocalized: "Source: Chamber and Senate agendas · as published today")
    }

    public var emptyFilterText: String {
        guard let theme else { return String(appLocalized: "No vote in this house lately.") }
        return String(appLocalized: "No recent vote about \(theme.title) with these filters.")
    }

    static func shortHouse(_ house: House) -> String {
        switch house {
        case .camara: String(appLocalized: "Chamber")
        case .senado: String(appLocalized: "Senate")
        }
    }
}
