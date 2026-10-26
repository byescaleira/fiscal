import FiscalDomain
import Foundation

public enum TodayText {
    public static func dateLine(_ day: CalendarDay, calendar: Calendar = FiscalCalendar.current)
        -> String
    {
        day.date(in: calendar).formatted(
            Date.FormatStyle(locale: .app, calendar: calendar).weekday(.wide).day().month(.wide))
    }

    public static func shortDate(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(locale: .app).day(.twoDigits).month(.twoDigits))
    }

    public static func stamp(_ date: Date) -> String {
        let time = date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: .app))
        return "\(shortDate(date)), \(time)"
    }

    public static func sourceLine(_ sources: [Source]) -> String? {
        let names = unique(sources.map(\.name))
        guard !names.isEmpty else { return nil }
        let list = names.formatted(.list(type: .and).locale(.app))
        guard let updated = sources.compactMap(\.updatedAt).max() else {
            return String(appLocalized: "Source: \(list)")
        }
        return String(appLocalized: "Source: \(list) · updated \(stamp(updated))")
    }

    public static func houseSourceLine(_ houses: [House], suffix: String) -> String? {
        let names = unique(houses.map(\.title))
        guard !names.isEmpty else { return nil }
        let list = names.formatted(.list(type: .and).locale(.app))
        return String(appLocalized: "Source: \(list) · \(suffix)")
    }

    public static func nextSession(_ date: Date?) -> String {
        guard let date else { return String(appLocalized: "Next session not scheduled yet") }
        let time = date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: .app))
        let day = date.formatted(Date.FormatStyle(locale: .app).weekday(.abbreviated).day())
        return String(appLocalized: "Next session: \(day) at \(time)")
    }

    public static func moreOnAgenda(_ count: Int) -> String {
        String(appLocalized: "More on the agenda: \(count)")
    }

    public static func moreFollowed(_ count: Int) -> String {
        String(appLocalized: "More in Mine: \(count)")
    }

    public static func kind(_ kind: TodayDigest.Event.Kind) -> String {
        switch kind {
        case .vote: String(appLocalized: "Vote")
        case .session: String(appLocalized: "Session")
        case .race: String(appLocalized: "Election count")
        case .law: String(appLocalized: "New law")
        }
    }

    public static func symbol(_ kind: TodayDigest.Event.Kind) -> String {
        switch kind {
        case .vote: "checkmark.square"
        case .session: "building.columns"
        case .race: "checkmark.seal"
        case .law: "doc.text"
        }
    }

    public static func voteLine(_ vote: VoteSummary) -> String {
        let day = shortDate(vote.date.date())
        return "\(vote.house.title) · \(vote.proposition) · \(day)"
    }

    public static func lensLine(_ lens: Lens?) -> String? {
        switch TodayBriefing.mode(for: lens) {
        case .plain: return nil
        case .themes(let themes):
            let list = themes.map(\.title).formatted(.list(type: .and).locale(.app))
            return String(
                appLocalized: "First: \(list). The facts are the same for everyone.")
        }
    }

    private static func unique(_ values: [String]) -> [String] {
        var seen: [String] = []
        for value in values where !seen.contains(value) { seen.append(value) }
        return seen
    }
}

public enum TodayBallot: Hashable, Sendable {
    case yes, no, abstention, absent
    case other(String)

    public init(_ text: String) {
        switch text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil) {
        case "sim": self = .yes
        case "nao": self = .no
        case "abstencao": self = .abstention
        case "ausente": self = .absent
        default: self = .other(text)
        }
    }

    public var title: String {
        switch self {
        case .yes: String(appLocalized: "Yes")
        case .no: String(appLocalized: "No")
        case .abstention: String(appLocalized: "Abstained")
        case .absent: String(appLocalized: "Absent")
        case .other(let text): text
        }
    }

    public var symbol: String {
        switch self {
        case .yes: "checkmark"
        case .no: "xmark"
        case .abstention: "minus"
        case .absent: "circle.dashed"
        case .other: "ellipsis"
        }
    }
}
