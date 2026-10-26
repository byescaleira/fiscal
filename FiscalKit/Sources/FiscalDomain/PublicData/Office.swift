import Foundation

public enum Office: String, CaseIterable, Codable, Identifiable, Sendable {
    case president, vicePresident, senator, federalDeputy, governor, viceGovernor, stateDeputy
    case mayor, viceMayor, cityCouncilor

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .president: String(appLocalized: "President")
        case .vicePresident: String(appLocalized: "Vice President")
        case .senator: String(appLocalized: "Senator")
        case .federalDeputy: String(appLocalized: "Federal Deputy")
        case .governor: String(appLocalized: "Governor")
        case .viceGovernor: String(appLocalized: "Vice Governor")
        case .stateDeputy: String(appLocalized: "State Deputy")
        case .mayor: String(appLocalized: "Mayor")
        case .viceMayor: String(appLocalized: "Vice Mayor")
        case .cityCouncilor: String(appLocalized: "City Councilor")
        }
    }

    public func title(for gender: Gender?) -> String {
        guard gender == .female else { return title }
        return switch self {
        case .president, .vicePresident: title
        case .senator: String(appLocalized: "Senator (female)")
        case .federalDeputy: String(appLocalized: "Federal Deputy (female)")
        case .governor: String(appLocalized: "Governor (female)")
        case .viceGovernor: String(appLocalized: "Vice Governor (female)")
        case .stateDeputy: String(appLocalized: "State Deputy (female)")
        case .mayor: String(appLocalized: "Mayor (female)")
        case .viceMayor: String(appLocalized: "Vice Mayor (female)")
        case .cityCouncilor: String(appLocalized: "City Councilor (female)")
        }
    }

    public var isFederal: Bool {
        switch self {
        case .president, .vicePresident, .senator, .federalDeputy: true
        case .governor, .viceGovernor, .stateDeputy, .mayor, .viceMayor, .cityCouncilor: false
        }
    }

    public var isMunicipal: Bool {
        switch self {
        case .mayor, .viceMayor, .cityCouncilor: true
        default: false
        }
    }

    public static func title(of raw: String, for gender: Gender? = nil) -> String {
        Office(rawValue: raw)?.title(for: gender) ?? raw
    }
}

public enum PersonStatus: String, CaseIterable, Codable, Sendable {
    case inOffice, electedAwaiting, onLeave

    public var title: String {
        switch self {
        case .inOffice: String(appLocalized: "In office")
        case .electedAwaiting: String(appLocalized: "Elected, awaiting inauguration")
        case .onLeave: String(appLocalized: "On leave")
        }
    }
}

public enum House: String, CaseIterable, Codable, Sendable {
    case camara, senado

    public var title: String {
        switch self {
        case .camara: String(appLocalized: "Chamber of Deputies")
        case .senado: String(appLocalized: "Federal Senate")
        }
    }
}
