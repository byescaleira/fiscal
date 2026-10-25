import FiscalDomain

public enum FeatureFlag: String, CaseIterable, Identifiable, Sendable {
    case guides

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .guides: String(appLocalized: "Guides")
        }
    }

    public var defaultValue: Bool {
        switch self {
        case .guides: true
        }
    }
}
