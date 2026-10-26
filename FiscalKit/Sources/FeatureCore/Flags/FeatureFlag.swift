import FiscalDomain

public enum FeatureFlag: String, CaseIterable, Identifiable, Sendable {
    case guides
    case partyIcons

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .guides: String(appLocalized: "Guides")
        case .partyIcons: String(appLocalized: "Party Icons")
        }
    }

    public var defaultValue: Bool {
        switch self {
        case .guides: true
        case .partyIcons: false
        }
    }
}
