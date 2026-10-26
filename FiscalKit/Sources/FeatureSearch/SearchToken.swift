import FiscalDomain
import Foundation

public enum SearchToken: Hashable, Identifiable, Sendable {
    case place(Place)
    case party(String)
    case theme(Theme)
    case electedAwaiting

    public var id: String {
        switch self {
        case .place(let place): "place-\(place.code)"
        case .party(let party): "party-\(SearchText.fold(party))"
        case .theme(let theme): "theme-\(theme.rawValue)"
        case .electedAwaiting: "elected-awaiting"
        }
    }

    public var title: String {
        switch self {
        case .place(let place):
            place.isState ? place.name : "\(place.name), \(place.uf.uppercased())"
        case .party(let party): party
        case .theme(let theme): theme.title
        case .electedAwaiting: String(appLocalized: "Elected in 2026")
        }
    }

    public var symbol: String {
        switch self {
        case .place(let place): place.isState ? "map" : "mappin.and.ellipse"
        case .party: "flag"
        case .theme(let theme): theme.symbol
        case .electedAwaiting: "checkmark.seal"
        }
    }

    func admits(_ card: PersonCard) -> Bool {
        switch self {
        case .place(let place): card.uf == place.uf || card.uf == "br"
        case .party(let party): SearchText.fold(card.party) == SearchText.fold(party)
        case .theme: false
        case .electedAwaiting: card.status == .electedAwaiting
        }
    }

    func admits(_ vote: VoteSummary) -> Bool {
        if case .theme(let theme) = self { return vote.themes.contains(theme) }
        return false
    }

    var filtersPeople: Bool {
        if case .theme = self { return false }
        return true
    }
}
