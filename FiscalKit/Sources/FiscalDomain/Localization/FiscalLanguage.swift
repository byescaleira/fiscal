public enum FiscalLanguage {
    public static let language = AppLanguage.portuguese

    public static func install(on setting: LanguageSetting = .shared) {
        setting.language = language
    }
}
