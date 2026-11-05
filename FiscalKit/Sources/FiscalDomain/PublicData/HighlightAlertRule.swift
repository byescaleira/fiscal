import Foundation

public struct HighlightAlertRule: Codable, Hashable, Sendable {
    public static let standard = HighlightAlertRule(minWeight: 70, maxAgeHours: 24)
    public static let lifetime: TimeInterval = 8 * 3_600

    public let minWeight: Int
    public let maxAgeHours: Int
    public let text: String?

    public init(minWeight: Int, maxAgeHours: Int, text: String? = nil) {
        self.minWeight = minWeight
        self.maxAgeHours = maxAgeHours
        self.text = text
    }

    public var summary: String {
        text
            ?? String(
                appLocalized:
                    "On the Lock Screen (Live Activity), only a highlight with weight \(minWeight) or more enters, for a fact up to \(maxAgeHours) hours after the end of its day (Brasília time), once a day at 8:00 on the device clock and for up to 8 hours."
            )
    }

    public static var brasilia: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo") ?? .current
        return calendar
    }

    public func passes(_ highlight: Highlight, now: Date = .now) -> Bool {
        guard highlight.weight >= minWeight else { return false }
        let calendar = Self.brasilia
        let start = highlight.date.date(in: calendar)
        guard start <= now,
            let end = calendar.date(byAdding: .day, value: 1, to: start)
        else { return false }
        return now.timeIntervalSince(end) <= TimeInterval(maxAgeHours) * 3_600
    }

    public func pick(from items: [Highlight], shown: Set<String>, now: Date = .now)
        -> Highlight?
    {
        items.first { !shown.contains($0.id) && passes($0, now: now) }
    }
}

public struct HighlightAlertLedger: Sendable {
    static let shownKey = "fiscal.highlightAlerts.shown"
    static let enabledKey = "fiscal.highlightAlerts.enabled"
    static let tokenKey = "fiscal.highlightAlerts.token"
    static let notificationKey = "fiscal.highlightAlerts.notification"
    static let planKey = "fiscal.highlightAlerts.plan"
    static let offsetKey = "fiscal.highlightAlerts.offset"
    public static let shownLimit = 60

    private let suiteName: String?

    public init(suiteName: String? = AppGroup.identifier) {
        self.suiteName = suiteName
    }

    private var defaults: UserDefaults? {
        guard let suiteName else { return .standard }
        return UserDefaults(suiteName: suiteName)
    }

    public var isEnabled: Bool {
        defaults?.object(forKey: Self.enabledKey) as? Bool ?? true
    }

    public func setEnabled(_ value: Bool) {
        defaults?.set(value, forKey: Self.enabledKey)
    }

    public var isNotificationEnabled: Bool {
        defaults?.bool(forKey: Self.notificationKey) ?? false
    }

    public func setNotificationEnabled(_ value: Bool) {
        defaults?.set(value, forKey: Self.notificationKey)
    }

    public var plan: HighlightAlertPlan {
        guard let data = defaults?.data(forKey: Self.planKey),
            let plan = try? JSONDecoder().decode(HighlightAlertPlan.self, from: data)
        else { return HighlightAlertPlan() }
        return plan
    }

    public func save(plan: HighlightAlertPlan) {
        defaults?.set(try? JSONEncoder().encode(plan), forKey: Self.planKey)
    }

    public func settle(now: Date) -> [String] {
        var plan = plan
        var passed: [String] = []
        if let activity = plan.activity, activity.hasPassed(now) {
            passed.append(activity.highlightId)
            plan.activity = nil
        }
        if let notification = plan.notification, notification.hasPassed(now) {
            passed.append(notification.highlightId)
            plan.notification = nil
        }
        passed.forEach(record)
        save(plan: plan)
        return passed
    }

    public func deviceOffset(
        draw: () -> Int = { Int.random(in: HighlightAlertSchedule.offsetRange) }
    ) -> Int {
        if let saved = defaults?.object(forKey: Self.offsetKey) as? Int { return saved }
        let offset = draw()
        defaults?.set(offset, forKey: Self.offsetKey)
        return offset
    }

    public func clearLegacyToken() {
        defaults?.removeObject(forKey: Self.tokenKey)
    }

    public var shown: Set<String> {
        Set(defaults?.stringArray(forKey: Self.shownKey) ?? [])
    }

    public func record(_ id: String) {
        var ids = defaults?.stringArray(forKey: Self.shownKey) ?? []
        guard !ids.contains(id) else { return }
        ids.append(id)
        defaults?.set(Array(ids.suffix(Self.shownLimit)), forKey: Self.shownKey)
    }
}
