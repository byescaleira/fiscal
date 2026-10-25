import FiscalDomain
import Foundation

extension MineModel {
    public static let resultLimit = 60

    public static let capitalCodes: Set<String> = [
        "1100205", "1200401", "1302603", "1400100", "1501402", "1600303", "1721000", "2111300",
        "2211001", "2304400", "2408102", "2507507", "2611606", "2704302", "2800308", "2927408",
        "3106200", "3205309", "3304557", "3550308", "4106902", "4205407", "4314902", "5002704",
        "5103403", "5208707", "5300108",
    ]

    public var states: [Place] {
        places.filter(\.isState).sorted(by: Self.byName)
    }

    public var capitals: [Place] {
        places.filter { Self.capitalCodes.contains($0.code) }.sorted(by: Self.byName)
    }

    public var hasCities: Bool { places.contains { !$0.isState } }

    public var placeResults: [Place] {
        let term = Self.normalized(query)
        guard !term.isEmpty else { return states }
        let matches = places.filter { place in
            name(of: place).contains(term) || (place.isState && place.uf == term)
        }
        let ordered = matches.sorted { lhs, rhs in
            if lhs.isState != rhs.isState { return lhs.isState }
            let lhsPrefix = name(of: lhs).hasPrefix(term)
            let rhsPrefix = name(of: rhs).hasPrefix(term)
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

    func name(of place: Place) -> String {
        searchNames[place.code] ?? Self.normalized(place.name)
    }

    static func normalized(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .lowercased()
            .split { !($0.isLetter || $0.isNumber) }
            .joined(separator: " ")
    }

    static func byName(_ lhs: Place, _ rhs: Place) -> Bool {
        lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }
}
