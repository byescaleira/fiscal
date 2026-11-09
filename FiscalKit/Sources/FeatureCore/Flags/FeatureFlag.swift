import FiscalDomain

public enum FeatureFlag: String, CaseIterable, Identifiable, Sendable {
    case guides
    case partyIcons
    case liveResults
    case highlightAlerts
    case intelligence

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .guides: String(appLocalized: "Guides")
        case .partyIcons: String(appLocalized: "Party Icons")
        case .liveResults: String(appLocalized: "Live Results")
        case .highlightAlerts: String(appLocalized: "Highlight Alerts")
        case .intelligence: String(appLocalized: "Apple Intelligence")
        }
    }

    public var defaultValue: Bool {
        switch self {
        case .guides, .liveResults, .highlightAlerts, .intelligence: true
        case .partyIcons: false
        }
    }
}
