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
        case .today: "newspaper"
        case .mine: "person.2"
        case .votes: "checklist"
        case .money: "banknote"
        case .search: "magnifyingglass"
        }
    }
}
