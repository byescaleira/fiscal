import FiscalDomain
import Foundation

@MainActor
public protocol RaceActivityTracking: AnyObject {
    var isAvailable: Bool { get }
    var onToken: (@MainActor (_ raceID: String, _ token: String) -> Void)? { get set }
    var onFinish: (@MainActor (_ token: String) -> Void)? { get set }
    func activeRaceIDs() -> Set<String>
    func start(_ race: Race) throws
    func resume()
    func update(_ race: Race) async
    func end(raceID: String) async -> [String]
}

#if canImport(ActivityKit) && os(iOS)
    import ActivityKit

    @MainActor
    public final class RaceActivities: RaceActivityTracking {
        public var onToken: (@MainActor (String, String) -> Void)?
        public var onFinish: (@MainActor (String) -> Void)?
        private var tasks: [String: [Task<Void, Never>]] = [:]
        private var tokens: [String: String] = [:]

        public init() {}

        public var isAvailable: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

        public func activeRaceIDs() -> Set<String> {
            Set(
                Activity<RaceActivityAttributes>.activities.filter(\.isLive).map(
                    \.attributes.raceId))
        }

        public func start(_ race: Race) throws {
            let content = ActivityContent(
                state: RaceActivityState(race: race),
                staleDate: .now.addingTimeInterval(RaceActivityPlan.staleAfter),
                relevanceScore: RaceActivityPlan.relevance(for: race.office))
            let attributes = RaceActivityAttributes(race: race)
            do {
                observe(
                    try Activity.request(attributes: attributes, content: content, pushType: .token)
                )
            } catch {
                observe(
                    try Activity.request(attributes: attributes, content: content, pushType: nil))
            }
        }

        public func resume() {
            for activity in Activity<RaceActivityAttributes>.activities where activity.isLive {
                guard tasks[activity.id] == nil else { continue }
                observe(activity)
            }
        }

        public func update(_ race: Race) async {
            for activity in Activity<RaceActivityAttributes>.activities
            where activity.attributes.raceId == race.id && activity.isLive {
                switch RaceActivityPlan.next(current: activity.content.state, race: race) {
                case .keep:
                    continue
                case .update(let state):
                    await activity.update(
                        ActivityContent(
                            state: state,
                            staleDate: .now.addingTimeInterval(RaceActivityPlan.staleAfter)))
                case .end(let state, let dismissAfter):
                    await activity.end(
                        ActivityContent(state: state, staleDate: nil),
                        dismissalPolicy: .after(.now.addingTimeInterval(dismissAfter)))
                }
            }
        }

        public func end(raceID: String) async -> [String] {
            var ended: [String] = []
            for activity in Activity<RaceActivityAttributes>.activities
            where activity.attributes.raceId == raceID {
                if let token = forget(activity.id) { ended.append(token) }
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            return ended
        }

        private func forget(_ id: String) -> String? {
            for task in tasks.removeValue(forKey: id) ?? [] { task.cancel() }
            return tokens.removeValue(forKey: id)
        }

        private func observe(_ activity: Activity<RaceActivityAttributes>) {
            let id = activity.id
            let raceID = activity.attributes.raceId
            let tokenTask = Task { [weak self] in
                for await data in activity.pushTokenUpdates {
                    let token = data.map { String(format: "%02x", $0) }.joined()
                    self?.tokens[id] = token
                    self?.onToken?(raceID, token)
                }
            }
            let stateTask = Task { [weak self] in
                for await state in activity.activityStateUpdates
                where state == .dismissed || state == .ended {
                    guard let self, let token = self.forget(id) else { return }
                    self.onFinish?(token)
                    return
                }
            }
            tasks[id] = [tokenTask, stateTask]
        }
    }

    extension Activity {
        fileprivate var isLive: Bool { activityState == .active || activityState == .stale }
    }
#else
    @MainActor
    public final class RaceActivities: RaceActivityTracking {
        public var onToken: (@MainActor (String, String) -> Void)?
        public var onFinish: (@MainActor (String) -> Void)?
        public init() {}
        public var isAvailable: Bool { false }
        public func activeRaceIDs() -> Set<String> { [] }
        public func start(_ race: Race) throws {}
        public func resume() {}
        public func update(_ race: Race) async {}
        public func end(raceID: String) async -> [String] { [] }
    }
#endif
