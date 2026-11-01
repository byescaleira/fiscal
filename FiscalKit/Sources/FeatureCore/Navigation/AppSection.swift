import FiscalDomain
import SwiftUI

public enum AppSection: String, CaseIterable, Identifiable, Sendable {
    case today, mine, votes, money, search

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .today: String(appLocalized: "Today")
        case .mine: String(appLocalized: "Mine")
        case .votes: String(appLocalized: "Votes")
        case .money: String(appLocalized: "Money")
        case .search: String(appLocalized: "Search")
        }
    }

    public var systemImage: String {
        switch self {
        case .today: "calendar.badge.checkmark"
        case .mine: "mappin.and.ellipse"
        case .votes: "checklist"
        case .money: "building.columns"
        case .search: "magnifyingglass"
        }
    }

    public var routePlaceholderTitle: String {
        switch self {
        case .today: String(appLocalized: "Choose a Highlight")
        case .mine: String(appLocalized: "Choose a Representative")
        case .votes: String(appLocalized: "Choose a Vote")
        case .money: String(appLocalized: "Choose an Expense")
        case .search: String(appLocalized: "Choose a Person")
        }
    }

    public var routePlaceholderMessage: String {
        switch self {
        case .today:
            String(appLocalized: "The highlight or vote you tap on the other half opens here.")
        case .mine: String(appLocalized: "The person you tap on the other half opens here.")
        case .votes:
            String(
                appLocalized: "The vote you tap on the other half opens here, with who voted how.")
        case .money:
            String(
                appLocalized:
                    "The spending you tap on the other half opens here, with the receipts.")
        case .search: String(appLocalized: "The person you find on the other half opens here.")
        }
    }

    public var routePlaceholderAnimation: FiscalAnimation { .launch }

    public enum SourceGroup: CaseIterable, Sendable {
        case followAlong, congress

        public var title: String {
            switch self {
            case .followAlong: String(appLocalized: "Follow Along")
            case .congress: String(appLocalized: "Congress")
            }
        }

        public var sections: [AppSection] {
            AppSection.allCases.filter { $0.sourceGroup == self }
        }
    }

    public var sourceGroup: SourceGroup {
        switch self {
        case .today, .mine: .followAlong
        case .votes, .money, .search: .congress
        }
    }

    public var shortcut: KeyEquivalent {
        let position = (Self.allCases.firstIndex(of: self) ?? .zero) + 1
        return KeyEquivalent(Character(String(position)))
    }

    public var role: TabRole? {
        guard self == .search else { return nil }
        if #available(iOS 27, macOS 27, visionOS 27, *) { return .prominent }
        return .search
    }
}
