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
    public var language: AppLanguage {
        didSet {
            defaults.set(language.rawValue, forKey: Key.language)
            if language == .system {
                defaults.removeObject(forKey: Key.systemLanguages)
            } else {
                defaults.set([language.rawValue], forKey: Key.systemLanguages)
            }
            languageSetting.language = language
        }
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
        let language =
            defaults.string(forKey: Key.language).flatMap(AppLanguage.init(rawValue:)) ?? .system
        languageSetting.language = language
        self.language = language
        appearance =
            defaults.string(forKey: Key.appearance).flatMap(Appearance.init(rawValue:)) ?? .system
        tint = defaults.string(forKey: Key.tint) ?? RetroColor.default.hex
    }

    public var locale: Locale { languageSetting.locale }

    private enum Key {
        static let appearance = "fiscal.settings.appearance"
        static let language = "fiscal.settings.language"
        static let systemLanguages = "AppleLanguages"
        static let tint = "fiscal.settings.tint"
    }
}
