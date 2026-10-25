import Foundation

public struct AppInfo: Sendable {
    public static let main = AppInfo(info: Bundle.main.infoDictionary ?? [:])

    public let version: String
    let number: String
    let appStoreURL: URL?
    let reviewURL: URL?
    let supportURL: URL?
    let helpURL: URL?
    let privacyURL: URL?
    let termsURL: URL?
    let websiteURL: URL?

    public init(info: [String: Any]) {
        func value(_ key: String) -> String? {
            (info[key] as? String).flatMap { $0.isEmpty ? nil : $0 }
        }
        let number = value("CFBundleShortVersionString") ?? "—"
        self.number = number
        version = value("CFBundleVersion").map { "\(number) (\($0))" } ?? number
        let store = value("FiscalAppStoreID").map { "https://apps.apple.com/app/id\($0)" }
        appStoreURL = store.flatMap(URL.init(string:))
        reviewURL = store.flatMap { URL(string: $0 + "?action=write-review") }
        supportURL = value("FiscalSupportEmail").flatMap { URL(string: "mailto:\($0)") }
        helpURL = value("FiscalHelpURL").flatMap(URL.init(string:))
        privacyURL = value("FiscalPrivacyURL").flatMap(URL.init(string:))
        termsURL = value("FiscalTermsURL").flatMap(URL.init(string:))
        websiteURL = value("FiscalWebsiteURL").flatMap(URL.init(string:))
    }

    var hasHelp: Bool { reviewURL != nil || supportURL != nil || helpURL != nil }
}
