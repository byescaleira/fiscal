import FiscalDomain

public enum TodayBriefing {
    public static func events(
        _ events: [TodayDigest.Event], hidesRaces: Bool
    ) -> [TodayDigest.Event] {
        hidesRaces ? events.filter { $0.kind != .race } : events
    }
}
