import FiscalDomain
import Foundation

@MainActor
public protocol HighlightActivityTracking: AnyObject {
    var isAvailable: Bool { get }
    var onStartToken: (@MainActor (_ token: String) -> Void)? { get set }
    var onShown: (@MainActor (_ highlightID: String) -> Void)? { get set }
    func activeHighlightIDs() -> Set<String>
    func observe()
    func start(_ highlight: Highlight, now: Date) async throws
    func endExpired(now: Date) async
    func endAll() async
}

#if canImport(ActivityKit) && os(iOS)
    import ActivityKit

    @MainActor
    public final class HighlightActivities: HighlightActivityTracking {
        public var onStartToken: (@MainActor (String) -> Void)?
        public var onShown: (@MainActor (String) -> Void)?
        private var tasks: [Task<Void, Never>] = []

        public init() {}

        public var isAvailable: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

        public func activeHighlightIDs() -> Set<String> {
            Set(live.map(\.attributes.highlightId))
        }

        public func observe() {
            guard tasks.isEmpty else { return }
            let tokens = Task { [weak self] in
                for await data in Activity<HighlightActivityAttributes>.pushToStartTokenUpdates {
                    let token = data.map { String(format: "%02x", $0) }.joined()
                    self?.onStartToken?(token)
                }
            }
            let arrivals = Task { [weak self] in
                for await activity in Activity<HighlightActivityAttributes>.activityUpdates {
                    let activityID = activity.id
                    let highlightID = activity.attributes.highlightId
                    await self?.arrived(activityID, highlightID: highlightID)
                }
            }
            tasks = [tokens, arrivals]
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

        private func arrived(_ activityID: String, highlightID: String) async {
            let others = live.filter { $0.id != activityID }
            if others.contains(where: { $0.attributes.highlightId == highlightID }) {
                await end([activityID])
                return
            }
            await end(Set(others.map(\.id)))
            onShown?(highlightID)
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
        public var onStartToken: (@MainActor (String) -> Void)?
        public var onShown: (@MainActor (String) -> Void)?
        public init() {}
        public var isAvailable: Bool { false }
        public func activeHighlightIDs() -> Set<String> { [] }
        public func observe() {}
        public func start(_ highlight: Highlight, now: Date) async throws {}
        public func endExpired(now: Date) async {}
        public func endAll() async {}
    }
#endif
