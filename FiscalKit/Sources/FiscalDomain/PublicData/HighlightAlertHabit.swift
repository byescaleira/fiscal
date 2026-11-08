import Foundation

public struct HighlightAlertHabit: Hashable, Sendable {
    public static let spacing: TimeInterval = 30 * 60
    public static let limit = 60
    public static let window: TimeInterval = 28 * 86_400
    public static let halfLife: TimeInterval = 7 * 86_400
    public static let hours = 7...21
    public static let minimumOpenings = 5
    public static let minimumDays = 3
    public static let gap = 4

    public let openings: [Date]

    public init(openings: [Date] = []) {
        self.openings = openings
    }

    public func recording(_ date: Date) -> HighlightAlertHabit {
        if let last = openings.last, date >= last, date.timeIntervalSince(last) < Self.spacing {
            return self
        }
        let kept = (openings + [date]).filter { date.timeIntervalSince($0) <= Self.window }
        return HighlightAlertHabit(openings: Array(kept.suffix(Self.limit)))
    }

    public func schedule(now: Date, calendar: Calendar = .current) -> HighlightAlertSchedule {
        let recent = openings.filter {
            $0 <= now && now.timeIntervalSince($0) <= Self.window
                && Self.hours.contains(calendar.component(.hour, from: $0))
        }
        let days = Set(recent.map { calendar.startOfDay(for: $0) })
        let order = ranked(recent, now: now, calendar: calendar)
        guard recent.count >= Self.minimumOpenings, days.count >= Self.minimumDays,
            let first = order.first
        else { return .standard }
        let standard = HighlightAlertSchedule.standard
        let second =
            order.first { abs($0 - first) >= Self.gap }
            ?? [standard.notificationHour, standard.activityHour].first {
                abs($0 - first) >= Self.gap
            }
            ?? standard.notificationHour
        return HighlightAlertSchedule(activityHour: first, notificationHour: second)
    }

    private func ranked(_ recent: [Date], now: Date, calendar: Calendar) -> [Int] {
        var weights: [Int: Double] = [:]
        for opening in recent {
            let hour = calendar.component(.hour, from: opening)
            weights[hour, default: 0] += pow(0.5, now.timeIntervalSince(opening) / Self.halfLife)
        }
        return weights.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .map(\.key)
    }
}
