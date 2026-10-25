import Foundation

public enum Theme: String, CaseIterable, Codable, Identifiable, Sendable {
    case health = "saude"
    case education = "educacao"
    case security = "seguranca"
    case economy = "economia"
    case taxes = "impostos"
    case environment = "ambiente"
    case city = "cidade"
    case transport = "transporte"
    case social = "social"
    case women = "mulheres"
    case countryside = "campo"
    case culture = "cultura"
    case rights = "direitos"
    case consumer = "consumidor"
    case technology = "tecnologia"
    case politics = "politica"
    case tributes = "homenagens"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .health: String(appLocalized: "Health")
        case .education: String(appLocalized: "Education")
        case .security: String(appLocalized: "Public security")
        case .economy: String(appLocalized: "Economy and jobs")
        case .taxes: String(appLocalized: "Taxes and public spending")
        case .environment: String(appLocalized: "Environment")
        case .city: String(appLocalized: "Cities and housing")
        case .transport: String(appLocalized: "Transport")
        case .social: String(appLocalized: "Social assistance")
        case .women: String(appLocalized: "Women")
        case .countryside: String(appLocalized: "Farming and countryside")
        case .culture: String(appLocalized: "Culture and sports")
        case .rights: String(appLocalized: "Rights and equality")
        case .consumer: String(appLocalized: "Consumers")
        case .technology: String(appLocalized: "Internet and technology")
        case .politics: String(appLocalized: "Politics and elections")
        case .tributes: String(appLocalized: "Tributes and names")
        }
    }

    public var symbol: String {
        switch self {
        case .health: "cross.case"
        case .education: "book"
        case .security: "shield"
        case .economy: "briefcase"
        case .taxes: "percent"
        case .environment: "leaf"
        case .city: "building.2"
        case .transport: "bus"
        case .social: "figure.2.and.child.holdinghands"
        case .women: "figure.stand.dress"
        case .countryside: "carrot"
        case .culture: "theatermasks"
        case .rights: "scalemass"
        case .consumer: "cart"
        case .technology: "cpu"
        case .politics: "building.columns"
        case .tributes: "rosette"
        }
    }
}
