import FiscalDomain
import Foundation

public enum ProfileChapter: String, CaseIterable, Identifiable, Sendable {
    case votes, proposals, money, origin, term, checks, about

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .votes: String(appLocalized: "How They Vote")
        case .proposals: String(appLocalized: "What They Propose")
        case .money: String(appLocalized: "What They Spend")
        case .origin: String(appLocalized: "Where They Come From")
        case .term: String(appLocalized: "During the Term")
        case .checks: String(appLocalized: "What Circulated")
        case .about: String(appLocalized: "Who They Are")
        }
    }

    public static func order(for office: Office) -> [ProfileChapter] {
        office.isLegislative ? allCases : [.origin, .term, .checks, .about]
    }
}

extension Office {
    var isLegislative: Bool {
        switch self {
        case .senator, .federalDeputy, .stateDeputy, .cityCouncilor: true
        case .president, .vicePresident, .governor, .viceGovernor, .mayor, .viceMayor: false
        }
    }
}
