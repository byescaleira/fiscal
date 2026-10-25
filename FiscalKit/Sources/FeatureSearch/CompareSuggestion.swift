import FiscalDomain
import Foundation

public struct CompareSuggestion: Hashable, Identifiable, Sendable {
    public static let limit = 3

    public let office: Office
    public let uf: String
    public let people: [PersonCard]

    public var id: String { "\(office.rawValue)-\(uf)" }

    public var slugs: [String] { people.map(\.slug) }

    public var title: String {
        "\(office.groupTitle) · \(uf.uppercased())"
    }

    public var names: String {
        people.map(\.name).formatted(.list(type: .and).locale(.app))
    }

    static func make(from cards: [PersonCard]) -> [CompareSuggestion] {
        let offices: [Office] = [.senator, .federalDeputy, .stateDeputy]
        let groups = Dictionary(
            grouping: cards.filter { offices.contains($0.office) && $0.status == .inOffice }
        ) { "\($0.office.rawValue)-\($0.uf)" }
        return
            groups.values
            .compactMap { group -> CompareSuggestion? in
                let people = Array(SearchIndex.alphabetical(group, by: \.name).prefix(limit))
                guard let first = people.first, people.count >= 2,
                    Set(people.map(\.party)).count >= 2
                else { return nil }
                return CompareSuggestion(office: first.office, uf: first.uf, people: people)
            }
            .sorted {
                let lhs = offices.firstIndex(of: $0.office) ?? 0
                let rhs = offices.firstIndex(of: $1.office) ?? 0
                return (lhs, $0.uf) < (rhs, $1.uf)
            }
            .prefix(limit)
            .map(\.self)
    }
}

extension Office {
    var groupTitle: String {
        switch self {
        case .president: String(appLocalized: "President")
        case .vicePresident: String(appLocalized: "Vice President")
        case .senator: String(appLocalized: "Senators")
        case .federalDeputy: String(appLocalized: "Federal deputies")
        case .governor: String(appLocalized: "Governors")
        case .viceGovernor: String(appLocalized: "Vice governors")
        case .stateDeputy: String(appLocalized: "State deputies")
        }
    }
}
