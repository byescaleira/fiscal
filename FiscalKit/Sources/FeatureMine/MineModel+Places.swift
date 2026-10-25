import FiscalDomain
import Foundation

extension MineModel {
    public static let resultLimit = 60

    public var states: [Place] {
        places.filter(\.isState).sorted(by: Self.byName)
    }

    public var placeResults: [Place] {
        let term = Self.normalized(query)
        guard !term.isEmpty else { return states }
        let matches = places.filter { place in
            Self.normalized(place.name).contains(term) || (place.isState && place.uf == term)
        }
        let ordered = matches.sorted { lhs, rhs in
            if lhs.isState != rhs.isState { return lhs.isState }
            let lhsPrefix = Self.normalized(lhs.name).hasPrefix(term)
            let rhsPrefix = Self.normalized(rhs.name).hasPrefix(term)
            if lhsPrefix != rhsPrefix { return lhsPrefix }
            return Self.byName(lhs, rhs)
        }
        return Array(ordered.prefix(Self.resultLimit))
    }

    public var isSearchingPlaces: Bool { !Self.normalized(query).isEmpty }

    public func placeDetail(_ place: Place) -> String {
        place.isState
            ? String(appLocalized: "State · \(place.uf.uppercased())")
            : stateName(place.uf).map { "\($0) · \(place.uf.uppercased())" }
                ?? place.uf.uppercased()
    }

    public func isChosen(_ place: Place) -> Bool { self.place?.code == place.code }

    func stateName(_ uf: String) -> String? {
        places.first { $0.isState && $0.uf == uf }?.name
    }

    static func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
    }

    static func byName(_ lhs: Place, _ rhs: Place) -> Bool {
        lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }
}
