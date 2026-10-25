import FiscalDomain
import Foundation

public enum GuideCategory: String, CaseIterable, Identifiable, Sendable {
    case start, personalize, data

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .start: String(appLocalized: "Start Here")
        case .personalize: String(appLocalized: "Personalize")
        case .data: String(appLocalized: "Data and Privacy")
        }
    }

    public var guides: [Guide] {
        Guide.allCases.filter { $0.category == self }
    }
}
