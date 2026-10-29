import FiscalDomain
import Testing

struct FiscalLanguageTests {
    @Test func installsBrazilianPortugueseWhateverTheSystemSays() {
        let setting = LanguageSetting(language: .system)
        FiscalLanguage.install(on: setting)
        #expect(setting.language == .portuguese)
        #expect(setting.locale.language.languageCode == "pt")
        #expect(setting.locale.region?.identifier == "BR")
    }
}
