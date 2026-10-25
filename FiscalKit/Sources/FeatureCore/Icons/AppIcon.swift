import FiscalDomain
import Foundation

public enum AppIcon: String, CaseIterable, Identifiable, Sendable {
    case standard
    case lens
    case iris
    case ballot
    case monogram

    public var id: String { rawValue }

    public init(assetName: String?) {
        self = Self.allCases.first { $0.assetName == assetName } ?? .standard
    }

    public var assetName: String? {
        switch self {
        case .standard: nil
        default: "FiscalIcon" + rawValue.prefix(1).uppercased() + rawValue.dropFirst()
        }
    }

    public var previewName: String { assetName ?? "FiscalIcon" }

    public var title: String {
        switch self {
        case .standard: String(appLocalized: "Classic")
        case .lens: String(appLocalized: "Magnifier")
        case .iris: String(appLocalized: "Watchful Eye")
        case .ballot: String(appLocalized: "Ballot Box")
        case .monogram: String(appLocalized: "Checked Document")
        }
    }
}
