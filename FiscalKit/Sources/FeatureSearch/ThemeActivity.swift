import FiscalDomain
import Foundation

public struct ThemeActivity: Equatable, Sendable {
    public struct Slice: Equatable, Identifiable, Sendable {
        public let theme: Theme
        public let slot: Int
        public let count: Int
        public let approved: Int
        public let rejected: Int

        public var id: String { theme.rawValue }
    }

    public struct Period: Equatable, Identifiable, Sendable {
        public let start: Date
        public let count: Int
        public let themes: [Theme]

        public var id: Date { start }
    }

    public enum Grain: Equatable, Sendable {
        case day, week

        public var seconds: TimeInterval {
            switch self {
            case .day: 86_400
            case .week: 604_800
            }
        }

        public var unit: Calendar.Component {
            switch self {
            case .day: .day
            case .week: .weekOfYear
            }
        }
    }

    public static let dailyLimit = 14

    public let total: Int
    public let slices: [Slice]
    public let periods: [Period]
    public let grain: Grain
    private let calendar: Calendar

    public init(
        votes: [VoteSummary], themes: [Theme], calendar: Calendar = FiscalCalendar.current
    ) {
        self.calendar = calendar
        total = votes.count
        slices = Self.slices(votes: votes, themes: themes)
        let touched = votes.filter { vote in vote.themes.contains { themes.contains($0) } }
        let days = touched.map { $0.date.date(in: calendar) }
        let span = Self.span(days, calendar: calendar)
        grain = span < Self.dailyLimit ? .day : .week
        periods = Self.periods(touched, themes: themes, grain: grain, calendar: calendar)
    }

    public var hasVotes: Bool { total > 0 }

    public var touchesThemes: Bool { slices.contains { $0.count > 0 } }

    public var maxCount: Int { slices.map(\.count).max() ?? 0 }

    public var leader: Slice? {
        guard let first = slices.first, first.count > 0 else { return nil }
        let second = slices.dropFirst().first?.count ?? 0
        return first.count > second ? first : nil
    }

    public var average: Double? {
        guard periods.count > 1 else { return nil }
        return Double(periods.map(\.count).reduce(0, +)) / Double(periods.count)
    }

    public static let axisLabelLimit = 5
    public static let visiblePeriods = 12

    public var isScrollable: Bool { periods.count > Self.visiblePeriods }

    public var visibleLength: TimeInterval {
        grain.seconds * Double(min(max(periods.count, 1), Self.visiblePeriods))
    }

    public var scrollStart: Date? {
        periods.dropLast(Self.visiblePeriods - 1).last?.start ?? periods.first?.start
    }

    public func slot(of theme: Theme) -> Int {
        slices.first { $0.theme == theme }?.slot ?? slices.count
    }

    public func showsLabel(at date: Date) -> Bool {
        guard let index = periods.firstIndex(where: { $0.start == date }) else { return false }
        let visible = min(periods.count, Self.visiblePeriods)
        let step = (visible + Self.axisLabelLimit - 1) / Self.axisLabelLimit
        return index.isMultiple(of: max(step, 1))
    }

    public static func placeholder(themes: [Theme]) -> ThemeActivity {
        let day = CalendarDay(year: 2026, month: 1, day: 1) ?? CalendarDay(Date.distantPast)
        let votes = themes.enumerated().flatMap { slot, theme in
            (0..<(themes.count - slot)).map { index in
                VoteSummary(
                    id: "\(theme.rawValue)-\(index)", house: .camara, date: day, time: nil,
                    proposition: "", kind: nil, summary: "", plainSummary: nil, themes: [theme],
                    result: nil, approved: nil, nominal: false,
                    tally: VoteSummary.Tally(yes: nil, no: nil, others: nil))
            }
        }
        return ThemeActivity(votes: votes, themes: themes)
    }

    public func period(at date: Date) -> Period? {
        guard let interval = calendar.dateInterval(of: grain.unit, for: date) else { return nil }
        return periods.first { interval.contains($0.start) }
    }

    public static func == (lhs: ThemeActivity, rhs: ThemeActivity) -> Bool {
        lhs.total == rhs.total && lhs.slices == rhs.slices && lhs.periods == rhs.periods
            && lhs.grain == rhs.grain
    }

    private static func slices(votes: [VoteSummary], themes: [Theme]) -> [Slice] {
        themes.enumerated().map { slot, theme in
            let matching = votes.filter { $0.themes.contains(theme) }
            return Slice(
                theme: theme, slot: slot, count: matching.count,
                approved: matching.count { $0.approved == true },
                rejected: matching.count { $0.approved == false })
        }
        .sorted { ($0.count, -$0.slot) > ($1.count, -$1.slot) }
    }

    private static func span(_ days: [Date], calendar: Calendar) -> Int {
        guard let first = days.min(), let last = days.max() else { return 0 }
        return (calendar.dateComponents([.day], from: first, to: last).day ?? 0) + 1
    }

    private static func periods(
        _ votes: [VoteSummary], themes: [Theme], grain: Grain, calendar: Calendar
    ) -> [Period] {
        let grouped = Dictionary(grouping: votes) { vote in
            calendar.dateInterval(of: grain.unit, for: vote.date.date(in: calendar))?.start
                ?? vote.date.date(in: calendar)
        }
        guard let first = grouped.keys.min(), let last = grouped.keys.max() else { return [] }
        var periods: [Period] = []
        var start = first
        while start <= last {
            let group = grouped[start] ?? []
            let present = themes.filter { theme in group.contains { $0.themes.contains(theme) } }
            periods.append(Period(start: start, count: group.count, themes: present))
            guard let next = calendar.date(byAdding: grain.unit, value: 1, to: start) else { break }
            start = next
        }
        return periods
    }
}
