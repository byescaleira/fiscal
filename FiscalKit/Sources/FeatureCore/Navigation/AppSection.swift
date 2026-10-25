import FiscalDomain
import SwiftUI

public enum AppSection: String, CaseIterable, Identifiable, Sendable {
    case home, settings

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .home: String(appLocalized: "Live Results")
        case .settings: String(appLocalized: "Settings")
        }
    }

    public var systemImage: String {
        switch self {
        case .home: "chart.bar.xaxis"
        case .settings: "gearshape"
        }
    }

    public var role: TabRole? {
        switch self {
        case .home, .settings: nil
        }
    }
}
