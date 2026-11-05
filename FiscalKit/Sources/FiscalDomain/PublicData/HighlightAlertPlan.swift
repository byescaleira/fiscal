import Foundation

public struct PlannedAlert: Codable, Hashable, Sendable {
    public let highlightId: String
    public let fireDate: Date

    public init(highlightId: String, fireDate: Date) {
        self.highlightId = highlightId
        self.fireDate = fireDate
    }

    public func hasPassed(_ now: Date) -> Bool { fireDate <= now }
}

public struct HighlightAlertPlan: Codable, Hashable, Sendable {
    public var activity: PlannedAlert?
    public var notification: PlannedAlert?

    public init(activity: PlannedAlert? = nil, notification: PlannedAlert? = nil) {
        self.activity = activity
        self.notification = notification
    }
}

public struct HighlightAlertSlots: Hashable, Sendable {
    public let activity: Date
    public let notification: Date

    public init(activity: Date, notification: Date) {
        self.activity = activity
        self.notification = notification
    }
}

public struct HighlightAlertSchedule: Hashable, Sendable {
    public static let standard = HighlightAlertSchedule(activityHour: 8, notificationHour: 19)
    public static let minimumLead: TimeInterval = 60
    public static let offsetRange = 0...600

    public let activityHour: Int
    public let notificationHour: Int

    public init(activityHour: Int, notificationHour: Int) {
        self.activityHour = activityHour
        self.notificationHour = notificationHour
    }

    public func next(hour: Int, offset: Int, now: Date, calendar: Calendar = .current) -> Date {
        let earliest = now.addingTimeInterval(Self.minimumLead)
        let today = calendar.startOfDay(for: now)
        for days in 0...1 {
            guard let day = calendar.date(byAdding: .day, value: days, to: today),
                let slot = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day)
            else { continue }
            let fire = slot.addingTimeInterval(TimeInterval(offset))
            if fire >= earliest { return fire }
        }
        return earliest
    }

    public func slots(offset: Int, now: Date, calendar: Calendar = .current)
        -> HighlightAlertSlots
    {
        HighlightAlertSlots(
            activity: next(hour: activityHour, offset: offset, now: now, calendar: calendar),
            notification: next(
                hour: notificationHour, offset: offset, now: now, calendar: calendar))
    }
}

public enum HighlightAlertPlanner {
    public static func plan(
        items: [Highlight], shown: Set<String>, excluding: Set<String> = [],
        rule: HighlightAlertRule, wantsActivity: Bool, wantsNotification: Bool,
        slots: HighlightAlertSlots
    ) -> HighlightAlertPlan {
        let taken = shown.union(excluding)
        let activity =
            wantsActivity ? rule.pick(from: items, shown: taken, now: slots.activity) : nil
        let notification =
            wantsNotification
            ? rule.pick(
                from: items, shown: taken.union(activity.map { [$0.id] } ?? []),
                now: slots.notification)
            : nil
        return HighlightAlertPlan(
            activity: activity.map {
                PlannedAlert(highlightId: $0.id, fireDate: slots.activity)
            },
            notification: notification.map {
                PlannedAlert(highlightId: $0.id, fireDate: slots.notification)
            })
    }
}
