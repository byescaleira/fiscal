import Foundation
import Observation
import Synchronization

@Observable
public final class LanguageSetting: Sendable {
    public static let shared = LanguageSetting()

    @ObservationIgnored private let storage: Mutex<Resolved>

    public init(language: AppLanguage = .system) {
        storage = Mutex(Resolved(language))
    }

    public var language: AppLanguage {
        get {
            access(keyPath: \.language)
            return storage.withLock { $0.language }
        }
        set {
            withMutation(keyPath: \.language) { storage.withLock { $0 = Resolved(newValue) } }
        }
    }

    public var locale: Locale {
        access(keyPath: \.language)
        return storage.withLock { $0.locale }
    }

    public var bundle: Bundle {
        access(keyPath: \.language)
        return storage.withLock { $0.bundle }
    }

    private struct Resolved: @unchecked Sendable {
        let language: AppLanguage
        let locale: Locale
        let bundle: Bundle

        init(_ language: AppLanguage) {
            self.language = language
            locale = language.locale
            bundle = language.bundle
        }
    }
}

extension Locale {
    public static var app: Locale { LanguageSetting.shared.locale }
}

extension String {
    public init(appLocalized key: String.LocalizationValue) {
        let setting = LanguageSetting.shared
        self.init(localized: key, bundle: setting.bundle, locale: setting.locale)
    }

    public static func localizations(of key: String.LocalizationValue) -> Set<String> {
        Set(
            AppLanguage.languages.map {
                String(localized: key, bundle: $0.bundle, locale: $0.locale)
            })
    }
}
