import FiscalDomain
import Testing

struct AppLanguageTests {
    @Test func offersTheTenLanguages() {
        #expect(AppLanguage.languages.count == 10)
        #expect(!AppLanguage.languages.contains(.system))
    }

    @Test func keepsTheChosenCode() {
        #expect(AppLanguage.portuguese.code == "pt-BR")
        #expect(AppLanguage.japanese.locale.language.languageCode == "ja")
    }
}
