import Foundation

public struct HighlightAlertRule: Codable, Hashable, Sendable {
    public static let standard = HighlightAlertRule(minWeight: 85, maxAgeHours: 24)
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
                    "On the Lock Screen (Live Activity), only a highlight with weight \(minWeight) or more enters, for a fact up to \(maxAgeHours) hours after the end of its day (Brasília time), once per device and for up to 8 hours."
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
    public static let shownLimit = 60

    private let suiteName: String?

    public init(suiteName: String? = HomePlace.appGroup) {
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

    public var shown: Set<String> {
        Set(defaults?.stringArray(forKey: Self.shownKey) ?? [])
    }

    public func record(_ id: String) {
        var ids = defaults?.stringArray(forKey: Self.shownKey) ?? []
        guard !ids.contains(id) else { return }
        ids.append(id)
        defaults?.set(Array(ids.suffix(Self.shownLimit)), forKey: Self.shownKey)
    }

    public var registeredToken: String? {
        defaults?.string(forKey: Self.tokenKey)
    }

    public func save(token: String?) {
        if let token {
            defaults?.set(token, forKey: Self.tokenKey)
        } else {
            defaults?.removeObject(forKey: Self.tokenKey)
        }
    }
}
