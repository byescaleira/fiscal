import FeatureCore
import FiscalDomain
import Foundation
import Observation

@MainActor @Observable
public final class SettingsModel {
    public var appearance: Appearance {
        didSet { defaults.set(appearance.rawValue, forKey: Key.appearance) }
    }
    public var tint: String {
        didSet { defaults.set(tint, forKey: Key.tint) }
    }
    public var highlightAlerts: Bool {
        didSet {
            guard highlightAlerts != oldValue else { return }
            alertLedger.setEnabled(highlightAlerts)
            highlightAlertsChanged(highlightAlerts)
        }
    }
    public private(set) var highlightNotifications: Bool
    public private(set) var notificationsDenied = false
    public var cloudSync: Bool {
        didSet { CloudSyncPreference.set(cloudSync, in: defaults) }
    }
    public var flags: FeatureFlags?
    public private(set) var appIcon: AppIcon
    public let info: AppInfo
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let languageSetting: LanguageSetting
    @ObservationIgnored private let iconSwitcher: any AppIconSwitching
    @ObservationIgnored private let alertLedger: HighlightAlertLedger
    @ObservationIgnored private let highlightAlertsChanged: @MainActor (Bool) -> Void
    @ObservationIgnored private let highlightNotificationChanged: @MainActor (Bool) async -> Bool
    @ObservationIgnored private let areNotificationsDenied: @MainActor () async -> Bool

    public init(
        defaults: UserDefaults = .standard, info: AppInfo = .main,
        languageSetting: LanguageSetting = .shared,
        iconSwitcher: any AppIconSwitching = SystemAppIconSwitcher(),
        alertLedger: HighlightAlertLedger = HighlightAlertLedger(),
        flags: FeatureFlags? = nil,
        highlightAlertsChanged: @escaping @MainActor (Bool) -> Void = { _ in },
        highlightNotificationChanged: @escaping @MainActor (Bool) async -> Bool = { _ in false },
        notificationsAreDenied: @escaping @MainActor () async -> Bool = { false }
    ) {
        self.defaults = defaults
        self.alertLedger = alertLedger
        self.highlightAlertsChanged = highlightAlertsChanged
        self.highlightNotificationChanged = highlightNotificationChanged
        areNotificationsDenied = notificationsAreDenied
        highlightAlerts = alertLedger.isEnabled
        highlightNotifications = alertLedger.isNotificationEnabled
        self.iconSwitcher = iconSwitcher
        appIcon = iconSwitcher.current
        self.info = info
        self.languageSetting = languageSetting
        self.flags = flags
        appearance =
            defaults.string(forKey: Key.appearance).flatMap(Appearance.init(rawValue:)) ?? .system
        tint = defaults.string(forKey: Key.tint) ?? RetroColor.default.hex
        cloudSync = CloudSyncPreference.isOn(in: defaults)
    }

    public func setHighlightNotifications(_ isOn: Bool) async {
        highlightNotifications = isOn
        let accepted = await highlightNotificationChanged(isOn)
        if isOn && !accepted { highlightNotifications = false }
        await refreshNotificationStatus()
    }

    public func refreshNotificationStatus() async {
        notificationsDenied = await areNotificationsDenied()
    }

    public var locale: Locale { languageSetting.locale }

    public var supportsAlternateIcons: Bool { iconSwitcher.supportsAlternateIcons }

    public func use(_ flags: FeatureFlags?) {
        guard let flags, self.flags !== flags else { return }
        self.flags = flags
    }

    public func setAppIcon(_ icon: AppIcon) async {
        guard icon != appIcon else { return }
        do {
            try await iconSwitcher.set(icon)
            appIcon = icon
        } catch {
            appIcon = iconSwitcher.current
        }
    }

    private enum Key {
        static let appearance = "fiscal.settings.appearance"
        static let tint = "fiscal.settings.tint"
    }
}
