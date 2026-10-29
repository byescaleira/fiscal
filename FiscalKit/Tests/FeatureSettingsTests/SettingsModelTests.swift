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
        let language = LanguageSetting()
        FiscalLanguage.install(on: language)
        let settings = SettingsModel(defaults: try defaults(), languageSetting: language)
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

    @Test func syncsWithICloudUntilTurnedOff() throws {
        let defaults = try defaults()
        #expect(CloudSyncPreference.isOn(in: defaults))
        let settings = SettingsModel(defaults: defaults, languageSetting: LanguageSetting())
        #expect(settings.cloudSync)
        settings.cloudSync = false
        #expect(defaults.bool(forKey: CloudSyncPreference.key) == false)
        #expect(!CloudSyncPreference.isOn(in: defaults))
        let reopened = SettingsModel(defaults: defaults, languageSetting: LanguageSetting())
        #expect(!reopened.cloudSync)
        #expect(reopened.cloudSyncValue == String(appLocalized: "Off"))
        #expect(!reopened.cloudFooter.isEmpty)
    }

    @Test func tellsTheInjectedObserverWhenHighlightAlertsChange() throws {
        var changes: [Bool] = []
        let settings = SettingsModel(
            defaults: try defaults(), languageSetting: LanguageSetting(),
            alertLedger: HighlightAlertLedger(suiteName: "SettingsModelTests.\(UUID().uuidString)"),
            highlightAlertsChanged: { changes.append($0) })
        #expect(settings.highlightAlerts)
        settings.highlightAlerts = false
        settings.highlightAlerts = false
        settings.highlightAlerts = true
        #expect(changes == [false, true])
        #expect(settings.highlightAlertsValue == String(appLocalized: "On"))
    }

    @Test func readsTheRowsFromTheFlags() throws {
        let defaults = try defaults()
        let settings = SettingsModel(defaults: defaults, languageSetting: LanguageSetting())
        #expect(settings.showsGuides)
        #expect(!settings.showsPartyIcons)
        #expect(!settings.showsDeveloper)

        let flags = FeatureFlags(defaults: defaults)
        settings.use(flags)
        flags.override(.guides, false)
        flags.override(.partyIcons, true)
        #expect(!settings.showsGuides)
        #expect(settings.showsPartyIcons)
        #expect(settings.showsDeveloper)
        settings.use(nil)
        #expect(settings.flags === flags)
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
