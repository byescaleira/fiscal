import FiscalDomain
import SwiftUI

public enum AppSection: String, CaseIterable, Identifiable, Sendable {
    case feed, votes, money, region, search

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .feed: String(appLocalized: "Feed")
        case .region: String(appLocalized: "Region")
        case .votes: String(appLocalized: "Votes")
        case .money: String(appLocalized: "Money")
        case .search: String(appLocalized: "Search")
        }
    }

    public var systemImage: String {
        switch self {
        case .feed: "newspaper"
        case .region: "map"
        case .votes: "checklist"
        case .money: "building.columns"
        case .search: "magnifyingglass"
        }
    }

    public var routePlaceholderTitle: String {
        switch self {
        case .feed: String(appLocalized: "Choose a Highlight")
        case .region: String(appLocalized: "Choose a Representative")
        case .votes: String(appLocalized: "Choose a Vote")
        case .money: String(appLocalized: "Choose an Expense")
        case .search: String(appLocalized: "Choose a Person")
        }
    }

    public var routePlaceholderMessage: String {
        switch self {
        case .feed:
            String(appLocalized: "The highlight or vote you tap on the other half opens here.")
        case .region: String(appLocalized: "The person you tap on the other half opens here.")
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
        case followAlong, congress, explore

        public var title: String {
            switch self {
            case .followAlong: String(appLocalized: "Follow Along")
            case .congress: String(appLocalized: "Congress")
            case .explore: String(appLocalized: "Explore")
            }
        }

        public var sections: [AppSection] {
            AppSection.allCases.filter { $0.sourceGroup == self }
        }
    }

    public var sourceGroup: SourceGroup {
        switch self {
        case .feed: .followAlong
        case .votes, .money: .congress
        case .region, .search: .explore
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
