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

    @Test func abbreviatesMoneyTheBrazilianWay() {
        let setting = LanguageSetting(language: .system)
        FiscalLanguage.install(on: setting)
        let text = PublicFormat.compactMoney(cents: 360_000_000, locale: setting.locale)
        #expect(text.contains("mi"))
        #expect(!text.contains("M"))
    }
}
