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
    public let appIcon = AppIcon.standard
    public let info: AppInfo
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let languageSetting: LanguageSetting

    public init(
        defaults: UserDefaults = .standard, info: AppInfo = .main,
        languageSetting: LanguageSetting = .shared
    ) {
        self.defaults = defaults
        self.info = info
        self.languageSetting = languageSetting
        appearance =
            defaults.string(forKey: Key.appearance).flatMap(Appearance.init(rawValue:)) ?? .system
        tint = defaults.string(forKey: Key.tint) ?? RetroColor.default.hex
    }

    public var locale: Locale { languageSetting.locale }

    private enum Key {
        static let appearance = "fiscal.settings.appearance"
        static let tint = "fiscal.settings.tint"
    }
}
