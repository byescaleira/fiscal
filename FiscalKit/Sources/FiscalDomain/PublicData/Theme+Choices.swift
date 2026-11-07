extension Theme {
    public static var causeChoices: [Theme] { neutralOrder }

    public static var neutralOrder: [Theme] {
        let leading: [Theme] = [
            .health, .education, .security, .economy, .taxes, .environment,
            .social, .rights, .politics, .city, .countryside, .women,
        ]
        return leading + allCases.filter { !leading.contains($0) }
    }

    public var coverage: String {
        switch self {
        case .health: String(appLocalized: "SUS, hospitals, medicines and vaccines")
        case .education: String(appLocalized: "Schools, universities and teachers")
        case .security: String(appLocalized: "Police, crime and prisons")
        case .economy: String(appLocalized: "Jobs, income, prices and companies")
        case .taxes: String(appLocalized: "Taxes, the budget and how public money is spent")
        case .environment: String(appLocalized: "Forests, climate, water and animals")
        case .city: String(appLocalized: "Housing, sanitation and urban life")
        case .transport: String(appLocalized: "Roads, traffic and public transport")
        case .social: String(appLocalized: "Bolsa Família, pensions and social aid")
        case .women: String(appLocalized: "Violence against women, work and care")
        case .countryside: String(appLocalized: "Agribusiness, family farming and land")
        case .culture: String(appLocalized: "Culture, sports and leisure")
        case .rights: String(appLocalized: "Human rights, minorities and equality")
        case .consumer: String(appLocalized: "Consumer rights, banks and services")
        case .technology: String(appLocalized: "Internet, data, science and innovation")
        case .politics: String(appLocalized: "Elections, parties and how Congress works")
        case .tributes: String(appLocalized: "Honors, commemorative dates and names")
        }
    }
}
