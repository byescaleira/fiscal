import FiscalDomain
import Foundation

@MainActor
public protocol HighlightActivityTracking: AnyObject {
    var isAvailable: Bool { get }
    func activeHighlightIDs() -> Set<String>
    func pendingHighlight() -> PlannedAlert?
    func schedule(_ highlight: Highlight, at date: Date) async throws
    func endPending() async
    func start(_ highlight: Highlight, now: Date) async throws
    func endExpired(now: Date) async
    func endAll() async
}

#if canImport(ActivityKit) && os(iOS)
    import ActivityKit

    @MainActor
    public final class HighlightActivities: HighlightActivityTracking {
        public init() {}

        public var isAvailable: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

        public func activeHighlightIDs() -> Set<String> {
            Set(live.map(\.attributes.highlightId))
        }

        public func pendingHighlight() -> PlannedAlert? {
            pending.first.map {
                PlannedAlert(
                    highlightId: $0.attributes.highlightId,
                    fireDate: $0.content.state.endDate.addingTimeInterval(
                        -HighlightAlertRule.lifetime))
            }
        }

        public func schedule(_ highlight: Highlight, at date: Date) async throws {
            let state = HighlightActivityState(highlight: highlight, now: date)
            let content = ActivityContent(
                state: state, staleDate: state.endDate, relevanceScore: 50)
            _ = try Activity.request(
                attributes: HighlightActivityAttributes(highlight: highlight), content: content,
                pushType: nil, style: .standard,
                alertConfiguration: AlertConfiguration(
                    title: LocalizedStringResource(stringLiteral: highlight.title),
                    body: LocalizedStringResource(stringLiteral: highlight.subtitle),
                    sound: .default),
                start: date)
        }

        public func endPending() async {
            for activity in Activity<HighlightActivityAttributes>.activities
            where activity.activityState == .pending {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }

        public func start(_ highlight: Highlight, now: Date) async throws {
            await end(Set(live.map(\.id)))
            let state = HighlightActivityState(highlight: highlight, now: now)
            let content = ActivityContent(
                state: state, staleDate: state.endDate, relevanceScore: 50)
            _ = try Activity.request(
                attributes: HighlightActivityAttributes(highlight: highlight), content: content,
                pushType: nil)
        }

        public func endExpired(now: Date) async {
            for activity in Activity<HighlightActivityAttributes>.activities
            where activity.content.state.endDate <= now || activity.activityState == .stale {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }

        public func endAll() async {
            for activity in Activity<HighlightActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }

        private var live: [Activity<HighlightActivityAttributes>] {
            Activity<HighlightActivityAttributes>.activities.filter {
                $0.activityState == .active || $0.activityState == .stale
            }
        }

        private var pending: [Activity<HighlightActivityAttributes>] {
            Activity<HighlightActivityAttributes>.activities.filter {
                $0.activityState == .pending
            }
        }

        private func end(_ ids: Set<String>) async {
            guard !ids.isEmpty else { return }
            for activity in Activity<HighlightActivityAttributes>.activities
            where ids.contains(activity.id) {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
#else
    @MainActor
    public final class HighlightActivities: HighlightActivityTracking {
        public init() {}
        public var isAvailable: Bool { false }
        public func activeHighlightIDs() -> Set<String> { [] }
        public func pendingHighlight() -> PlannedAlert? { nil }
        public func schedule(_ highlight: Highlight, at date: Date) async throws {}
        public func endPending() async {}
        public func start(_ highlight: Highlight, now: Date) async throws {}
        public func endExpired(now: Date) async {}
        public func endAll() async {}
    }
#endif
