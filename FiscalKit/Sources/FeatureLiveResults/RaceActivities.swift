import FiscalDomain
import Foundation

@MainActor
public protocol RaceActivityTracking: AnyObject {
    var isAvailable: Bool { get }
    func activeRaceIDs() -> Set<String>
    func start(_ race: Race, onToken: @escaping @MainActor (String) -> Void) throws
    func resume(onToken: @escaping @MainActor (String, String) -> Void)
    func update(_ race: Race) async
    func end(raceID: String) async -> [String]
}

#if canImport(ActivityKit) && os(iOS)
    import ActivityKit

    @MainActor
    public final class RaceActivities: RaceActivityTracking {
        private var tokenTasks: [String: Task<Void, Never>] = [:]
        private var tokens: [String: String] = [:]

        public init() {}

        public var isAvailable: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

        public func activeRaceIDs() -> Set<String> {
            Set(
                Activity<RaceActivityAttributes>.activities.filter(\.isLive).map(
                    \.attributes.raceId))
        }

        public func start(_ race: Race, onToken: @escaping @MainActor (String) -> Void) throws {
            let content = ActivityContent(
                state: RaceActivityState(race: race), staleDate: .now.addingTimeInterval(600),
                relevanceScore: race.office == .president ? 100 : 50)
            let activity = try Activity.request(
                attributes: RaceActivityAttributes(race: race), content: content, pushType: .token)
            observe(activity) { _, token in onToken(token) }
        }

        public func resume(onToken: @escaping @MainActor (String, String) -> Void) {
            for activity in Activity<RaceActivityAttributes>.activities where activity.isLive {
                guard tokenTasks[activity.id] == nil else { continue }
                observe(activity, onToken: onToken)
            }
        }

        public func update(_ race: Race) async {
            for activity in Activity<RaceActivityAttributes>.activities
            where activity.attributes.raceId == race.id && activity.isLive {
                let state = RaceActivityState(race: race)
                guard state != activity.content.state else { continue }
                let content = ActivityContent(state: state, staleDate: .now.addingTimeInterval(600))
                if race.final {
                    await activity.end(
                        content, dismissalPolicy: .after(.now.addingTimeInterval(14_400)))
                } else {
                    await activity.update(content)
                }
            }
        }

        public func end(raceID: String) async -> [String] {
            var ended: [String] = []
            for activity in Activity<RaceActivityAttributes>.activities
            where activity.attributes.raceId == raceID {
                if let token = tokens.removeValue(forKey: activity.id) { ended.append(token) }
                tokenTasks.removeValue(forKey: activity.id)?.cancel()
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            return ended
        }

        private func observe(
            _ activity: Activity<RaceActivityAttributes>,
            onToken: @escaping @MainActor (String, String) -> Void
        ) {
            let id = activity.id
            let raceID = activity.attributes.raceId
            tokenTasks[id] = Task { [weak self] in
                for await data in activity.pushTokenUpdates {
                    let token = data.map { String(format: "%02x", $0) }.joined()
                    self?.tokens[id] = token
                    onToken(raceID, token)
                }
            }
        }
    }

    extension Activity {
        fileprivate var isLive: Bool { activityState == .active || activityState == .stale }
    }
#else
    @MainActor
    public final class RaceActivities: RaceActivityTracking {
        public init() {}
        public var isAvailable: Bool { false }
        public func activeRaceIDs() -> Set<String> { [] }
        public func start(_ race: Race, onToken: @escaping @MainActor (String) -> Void) throws {}
        public func resume(onToken: @escaping @MainActor (String, String) -> Void) {}
        public func update(_ race: Race) async {}
        public func end(raceID: String) async -> [String] { [] }
    }
#endif
