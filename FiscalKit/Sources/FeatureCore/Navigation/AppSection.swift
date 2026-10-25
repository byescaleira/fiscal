import FiscalDomain
import SwiftUI

public enum AppSection: String, CaseIterable, Identifiable, Sendable {
    case today, settings

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .today: String(appLocalized: "Today")
        case .settings: String(appLocalized: "Settings")
        }
    }

    public var systemImage: String {
        switch self {
        case .today: "newspaper"
        case .settings: "gearshape"
        }
    }

    public var role: TabRole? {
        switch self {
        case .today, .settings: nil
        }
    }
}
