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
            Self.onHighlightAlertsChange?(highlightAlerts)
        }
    }
    public private(set) var appIcon: AppIcon
    public static var onHighlightAlertsChange: (@MainActor (Bool) -> Void)?
    public let info: AppInfo
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let languageSetting: LanguageSetting
    @ObservationIgnored private let iconSwitcher: any AppIconSwitching
    @ObservationIgnored private let alertLedger: HighlightAlertLedger

    public init(
        defaults: UserDefaults = .standard, info: AppInfo = .main,
        languageSetting: LanguageSetting = .shared,
        iconSwitcher: any AppIconSwitching = SystemAppIconSwitcher(),
        alertLedger: HighlightAlertLedger = HighlightAlertLedger()
    ) {
        self.defaults = defaults
        self.alertLedger = alertLedger
        highlightAlerts = alertLedger.isEnabled
        self.iconSwitcher = iconSwitcher
        appIcon = iconSwitcher.current
        self.info = info
        self.languageSetting = languageSetting
        appearance =
            defaults.string(forKey: Key.appearance).flatMap(Appearance.init(rawValue:)) ?? .system
        tint = defaults.string(forKey: Key.tint) ?? RetroColor.default.hex
    }

    public var locale: Locale { languageSetting.locale }

    public var supportsAlternateIcons: Bool { iconSwitcher.supportsAlternateIcons }

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
