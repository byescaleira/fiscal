import Foundation

public enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case portuguese = "pt-BR"

    public var id: String { rawValue }

    public static var languages: [AppLanguage] { allCases.filter { $0 != .system } }

    public var nativeName: String {
        switch self {
        case .system: String(appLocalized: "System")
        case .portuguese: "Português (Brasil)"
        }
    }

    public var code: String {
        self == .system ? AppLanguage.portuguese.rawValue : rawValue
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
