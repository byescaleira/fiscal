import Foundation

public enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case english = "en"
    case portuguese = "pt-BR"
    case spanish = "es"
    case german = "de"
    case french = "fr"
    case italian = "it"
    case japanese = "ja"
    case korean = "ko"
    case chinese = "zh-Hans"
    case russian = "ru"

    public var id: String { rawValue }

    public static var languages: [AppLanguage] { allCases.filter { $0 != .system } }

    public var nativeName: String {
        switch self {
        case .system: String(appLocalized: "System")
        case .english: "English"
        case .portuguese: "Português (Brasil)"
        case .spanish: "Español (España)"
        case .german: "Deutsch (Deutschland)"
        case .french: "Français (France)"
        case .italian: "Italiano"
        case .japanese: "日本語"
        case .korean: "한국어"
        case .chinese: "简体中文"
        case .russian: "Русский"
        }
    }

    public var code: String {
        guard self == .system else { return rawValue }
        let preferences =
            UserDefaults.standard.stringArray(forKey: "AppleLanguages") ?? Locale.preferredLanguages
        let available = Bundle.main.localizations.filter { $0 != "Base" }
        return Bundle.preferredLocalizations(from: available, forPreferences: preferences).first
            ?? "en"
    }

    public var locale: Locale {
        var components = Locale.Components(identifier: code)
        if components.region == nil { components.region = Locale.current.region }
        return Locale(components: components)
    }

    public var bundle: Bundle {
        Bundle.main.path(forResource: code, ofType: "lproj").flatMap(Bundle.init(path:))
            ?? .main
    }
}
