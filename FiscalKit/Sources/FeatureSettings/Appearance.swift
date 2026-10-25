import FiscalDomain
import SwiftUI

public enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark

    public var id: String { rawValue }

    var title: String {
        switch self {
        case .system: String(appLocalized: "Automatic")
        case .light: String(appLocalized: "Light")
        case .dark: String(appLocalized: "Dark")
        }
    }
}
