import FeatureCore
import FiscalDomain

extension FiscalServices {
    public func holdConnections() -> [UpdateHoldModel.Connection] {
        [
            UpdateHoldModel.Connection {
                await HighlightAlertCenter.shared.resume()
            } stop: {
                await HighlightAlertCenter.shared.hold()
            },
            UpdateHoldModel.Connection {
                OfflineDataCenter.shared.scheduleBackgroundRefresh()
            } stop: {
                OfflineDataCenter.shared.cancelBackgroundRefresh()
            },
        ]
    }
}
