import FeatureCore
import FiscalDomain

struct HeldLiveResultsService: LiveResultsService {
    let base: any LiveResultsService
    let gate: HoldGate

    func races() async throws -> [Race] {
        try await base.races()
    }

    func follow(raceID: String, pushToken: String, environment: PushEnvironment) async throws {
        guard await !gate.isHeld else { throw LiveResultsError.unavailable }
        try await base.follow(raceID: raceID, pushToken: pushToken, environment: environment)
    }

    func unfollow(pushToken: String) async throws {
        try await base.unfollow(pushToken: pushToken)
    }
}

extension FiscalServices {
    public func holdConnections() -> [UpdateHoldModel.Connection] {
        [
            UpdateHoldModel.Connection {
                await HighlightAlertCenter.shared.resume()
            } stop: {
                await HighlightAlertCenter.shared.hold()
            },
            raceRegistration.connection,
            UpdateHoldModel.Connection {
                OfflineDataCenter.shared.scheduleBackgroundRefresh()
            } stop: {
                OfflineDataCenter.shared.cancelBackgroundRefresh()
            },
        ]
    }
}
