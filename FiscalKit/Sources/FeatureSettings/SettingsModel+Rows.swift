import FeatureCore
import FiscalDomain
import Foundation

extension SettingsModel {
    public var showsGuides: Bool { flags?.isOn(.guides) != false }

    public var showsPartyIcons: Bool { flags?.isOn(.partyIcons) == true }

    public var showsDeveloper: Bool {
        #if DEBUG
            flags != nil
        #else
            false
        #endif
    }

    public var isCloudSyncAvailable: Bool {
        #if targetEnvironment(simulator)
            false
        #else
            true
        #endif
    }

    var cloudSyncValue: String {
        Self.onOff(isCloudSyncAvailable && cloudSync)
    }

    var cloudFooter: String {
        guard isCloudSyncAvailable else {
            return String(appLocalized: "iCloud sync is off in the Simulator.")
        }
        return String(
            appLocalized:
                "Who you follow and your investigations sync through your own iCloud account. The change applies the next time you open Fiscal."
        )
    }

    var highlightAlertsValue: String { Self.onOff(highlightAlerts) }

    static func onOff(_ isOn: Bool) -> String {
        isOn ? String(appLocalized: "On") : String(appLocalized: "Off")
    }
}
