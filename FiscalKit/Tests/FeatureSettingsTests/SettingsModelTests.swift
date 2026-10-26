import FeatureCore
import FiscalDomain
import Foundation
import Testing

@testable import FeatureSettings

@MainActor
struct SettingsModelTests {
    private func defaults() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: "SettingsModelTests.\(UUID().uuidString)"))
    }

    @Test func startsWithTheSystemLookAndTheDefaultTint() throws {
        let settings = SettingsModel(defaults: try defaults(), languageSetting: LanguageSetting())
        #expect(settings.appearance == .system)
        #expect(settings.tintName == RetroColor.default.name)
    }

    @Test func alwaysSpeaksBrazilianPortuguese() throws {
        let settings = SettingsModel(defaults: try defaults(), languageSetting: LanguageSetting())
        #expect(settings.locale.language.languageCode == "pt")
    }

    @Test func persistsTheChoices() throws {
        let defaults = try defaults()
        let settings = SettingsModel(defaults: defaults, languageSetting: LanguageSetting())
        settings.appearance = .dark
        settings.tint = RetroColor.teal.hex
        let reopened = SettingsModel(defaults: defaults, languageSetting: LanguageSetting())
        #expect(reopened.appearance == .dark)
        #expect(reopened.tint == RetroColor.teal.hex)
    }

    @Test func readsVersionAndLinksFromTheInfoDictionary() {
        let info = AppInfo(info: [
            "CFBundleShortVersionString": "1.2", "CFBundleVersion": "7",
            "FiscalPrivacyURL": "https://example.com/privacy", "FiscalHelpURL": "",
        ])
        #expect(info.version == "1.2 (7)")
        #expect(info.links.map(\.kind) == [.privacy])
    }
}
