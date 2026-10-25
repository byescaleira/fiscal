import FiscalDomain
import SwiftUI

public enum AppSection: String, CaseIterable, Identifiable, Sendable {
    case home, settings

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .home: String(appLocalized: "Home")
        case .settings: String(appLocalized: "Settings")
        }
    }

    public var systemImage: String {
        switch self {
        case .home: "house"
        case .settings: "gearshape"
        }
    }

    public var role: TabRole? {
        switch self {
        case .home, .settings: nil
        }
    }
}
