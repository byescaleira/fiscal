import FiscalDomain
import Foundation

extension TodayModel {
    public var lensLine: String? { Self.lensLine(lens) }

    public var dateLine: String {
        Self.dateLine(digest?.date ?? agenda?.date ?? CalendarDay(now()))
    }

    public var dateKicker: String { dateLine.uppercased(with: .app) }

    public var digestSource: String? { Self.sourceLine(sources) }

    public var agendaSource: String? {
        guard let agenda, !agenda.houses.isEmpty else { return nil }
        let date = Self.shortDate(agenda.date.date())
        return Self.houseSourceLine(
            agenda.houses.map(\.house), suffix: String(appLocalized: "agenda of \(date)"))
    }

    public var recentSource: String? {
        guard let latest = recentVotes.map(\.date).max() else { return nil }
        let date = Self.shortDate(latest.date())
        return Self.houseSourceLine(
            recentVotes.map(\.house), suffix: String(appLocalized: "votes up to \(date)"))
    }

    public var moreFollowedText: String? {
        moreFollowed > 0 ? String(appLocalized: "More in Mine: \(moreFollowed)") : nil
    }

    public func detail(for card: PersonCard) -> String {
        card.uf == "br" ? card.officeTitle : "\(card.officeTitle) · \(card.uf.uppercased())"
    }

    public func failureTitle(_ error: PublicDataError) -> String {
        error == .offline
            ? error.title : String(appLocalized: "Couldn't load the summary of the day")
    }

    public func shownItems(_ house: HouseAgenda) -> [LensOrdered<AgendaItem>] {
        Array(house.items.prefix(Self.agendaLimit))
    }

    public func moreOnAgendaText(_ house: HouseAgenda) -> String? {
        let hidden = house.items.count - shownItems(house).count
        return hidden > 0 ? String(appLocalized: "More on the agenda: \(hidden)") : nil
    }

    public func nextSessionText(_ day: Agenda.HouseDay) -> String {
        guard let date = day.nextSession else {
            return String(appLocalized: "Next session not scheduled yet")
        }
        let time = date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: .app))
        let weekday = date.formatted(Date.FormatStyle(locale: .app).weekday(.abbreviated).day())
        return String(appLocalized: "Next session: \(weekday) at \(time)")
    }

    public func kindKicker(_ kind: TodayDigest.Event.Kind) -> String {
        Self.kindTitle(kind).uppercased(with: .app)
    }

    public func kindSymbol(_ kind: TodayDigest.Event.Kind) -> String { Self.symbol(kind) }

    public func eventSymbol(_ event: TodayDigest.Event) -> String {
        event.themes.first?.symbol ?? Self.symbol(event.kind)
    }

    public func voteLine(_ vote: VoteSummary) -> String {
        "\(vote.house.title) · \(vote.heading) · \(Self.shortDate(vote.date.date()))"
    }

    public func highlightOverline(_ highlight: Highlight) -> String {
        highlightKicker(highlight).uppercased(with: .app)
    }

    public func highlightHeroOverline(_ highlight: Highlight) -> String {
        highlightHeroKicker(highlight).uppercased(with: .app)
    }

    public func authorLine(_ person: PersonCard) -> String {
        "\(person.officeTitle) · \(person.uf.uppercased(with: .app))"
    }

    nonisolated public static func dateLine(
        _ day: CalendarDay, calendar: Calendar = GregorianCalendar.current
    ) -> String {
        day.date(in: calendar).formatted(
            Date.FormatStyle(locale: .app, calendar: calendar).weekday(.wide).day().month(.wide))
    }

    nonisolated public static func shortDate(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(locale: .app).day(.twoDigits).month(.twoDigits))
    }

    nonisolated public static func stamp(_ date: Date) -> String {
        let time = date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: .app))
        return "\(shortDate(date)), \(time)"
    }

    nonisolated public static func sourceLine(_ sources: [Source]) -> String? {
        let names = unique(sources.map(\.name))
        guard !names.isEmpty else { return nil }
        let list = names.formatted(.list(type: .and).locale(.app))
        guard let updated = sources.compactMap(\.updatedAt).max() else {
            return String(appLocalized: "Source: \(list)")
        }
        return String(appLocalized: "Source: \(list) · updated \(stamp(updated))")
    }

    nonisolated public static func houseSourceLine(_ houses: [House], suffix: String) -> String? {
        let names = unique(houses.map(\.title))
        guard !names.isEmpty else { return nil }
        let list = names.formatted(.list(type: .and).locale(.app))
        return String(appLocalized: "Source: \(list) · \(suffix)")
    }

    nonisolated public static func kindTitle(_ kind: TodayDigest.Event.Kind) -> String {
        switch kind {
        case .vote: String(appLocalized: "Vote")
        case .session: String(appLocalized: "Session")
        case .race: String(appLocalized: "Election count")
        case .law: String(appLocalized: "New law")
        }
    }

    nonisolated public static func symbol(_ kind: TodayDigest.Event.Kind) -> String {
        switch kind {
        case .vote: "checkmark.square"
        case .session: "building.columns"
        case .race: "checkmark.seal"
        case .law: "doc.text"
        }
    }

    nonisolated public static func lensLine(_ lens: Lens?) -> String? {
        switch TodayBriefing.mode(for: lens) {
        case .plain: return nil
        case .themes(let themes):
            let list = themes.map(\.title).formatted(.list(type: .and).locale(.app))
            return String(
                appLocalized: "First: \(list). The facts are the same for everyone.")
        }
    }

    nonisolated private static func unique(_ values: [String]) -> [String] {
        var seen: [String] = []
        for value in values where !seen.contains(value) { seen.append(value) }
        return seen
    }
}
