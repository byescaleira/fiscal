import FiscalDomain
import SwiftUI

public enum Guide: String, CaseIterable, Identifiable, Sendable {
    case tour, appearance, privacy

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .tour: String(appLocalized: "Meet Fiscal")
        case .appearance: String(appLocalized: "Make It Yours")
        case .privacy: String(appLocalized: "Privacy")
        }
    }

    public var subtitle: String {
        switch self {
        case .tour: String(appLocalized: "The tabs and what each one shows")
        case .appearance: String(appLocalized: "Theme and accent color")
        case .privacy: String(appLocalized: "Where your data lives")
        }
    }

    public var systemImage: String {
        switch self {
        case .tour: "sparkles"
        case .appearance: "paintbrush"
        case .privacy: "lock.shield"
        }
    }

    public var animation: FiscalAnimation {
        switch self {
        case .tour: .launch
        case .appearance: .editor
        case .privacy: .privacy
        }
    }

    public var category: GuideCategory {
        switch self {
        case .tour: .start
        case .appearance: .personalize
        case .privacy: .data
        }
    }

    public var minutes: Int {
        switch self {
        case .tour: 2
        case .appearance, .privacy: 1
        }
    }
}

public struct ShowGuideAction {
    private let action: (Guide) -> Void

    public init(_ action: @escaping (Guide) -> Void) {
        self.action = action
    }

    public func callAsFunction(_ guide: Guide) {
        action(guide)
    }
}

extension EnvironmentValues {
    @Entry public var showGuide: ShowGuideAction?
}
