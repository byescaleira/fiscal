import FiscalDomain
import Testing

struct AppLanguageTests {
    @Test func speaksOnlyBrazilianPortuguese() {
        #expect(AppLanguage.languages == [.portuguese])
        #expect(!AppLanguage.languages.contains(.system))
    }

    @Test func theSystemChoiceResolvesToBrazilianPortuguese() {
        #expect(AppLanguage.system.code == "pt-BR")
        #expect(AppLanguage.portuguese.code == "pt-BR")
        #expect(AppLanguage.system.locale.language.languageCode == "pt")
        #expect(AppLanguage.portuguese.locale.region?.identifier == "BR")
    }
}
