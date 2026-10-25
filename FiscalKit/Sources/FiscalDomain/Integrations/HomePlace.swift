import Foundation

public struct HomePlace: Sendable {
    public static let appGroup = "group.com.byescaleira"
    public static let mineKey = "FiscalMinePlace"
    static let ufKey = "fiscal.widgets.uf"
    static let scenarioKey = "fiscal.widgets.scenario"

    public static let states = [
        "ac", "al", "am", "ap", "ba", "ce", "df", "es", "go", "ma", "mg", "ms", "mt", "pa",
        "pb", "pe", "pi", "pr", "rj", "rn", "ro", "rr", "rs", "sc", "se", "sp", "to",
    ]

    private static let ibgePrefixes: [String: String] = [
        "11": "ro", "12": "ac", "13": "am", "14": "rr", "15": "pa", "16": "ap", "17": "to",
        "21": "ma", "22": "pi", "23": "ce", "24": "rn", "25": "pb", "26": "pe", "27": "al",
        "28": "se", "29": "ba", "31": "mg", "32": "es", "33": "rj", "35": "sp", "41": "pr",
        "42": "sc", "43": "rs", "50": "ms", "51": "mt", "52": "go", "53": "df",
    ]

    private let suiteName: String?

    public init(suiteName: String? = HomePlace.appGroup) {
        self.suiteName = suiteName
    }

    private var defaults: UserDefaults? {
        guard let suiteName else { return .standard }
        return UserDefaults(suiteName: suiteName)
    }

    public var uf: String? {
        defaults?.string(forKey: Self.ufKey).flatMap(Self.uf(fromPlaceCode:))
    }

    @discardableResult
    public func save(uf: String?) -> Bool {
        let value = uf.flatMap(Self.uf(fromPlaceCode:))
        guard value != self.uf else { return false }
        if let value {
            defaults?.set(value, forKey: Self.ufKey)
        } else {
            defaults?.removeObject(forKey: Self.ufKey)
        }
        return true
    }

    public var scenario: String? {
        defaults?.string(forKey: Self.scenarioKey)
    }

    @discardableResult
    public func save(scenario: String?) -> Bool {
        guard scenario != self.scenario else { return false }
        if let scenario {
            defaults?.set(scenario, forKey: Self.scenarioKey)
        } else {
            defaults?.removeObject(forKey: Self.scenarioKey)
        }
        return true
    }

    public static func chosenUF(in defaults: UserDefaults) -> String? {
        defaults.string(forKey: mineKey).flatMap(uf(fromPlaceCode:))
    }

    public static func uf(fromPlaceCode code: String) -> String? {
        let value = code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if states.contains(value) { return value }
        guard value.count == 7, value.allSatisfy(\.isNumber) else { return nil }
        return ibgePrefixes[String(value.prefix(2))]
    }

    public static func name(of uf: String) -> String {
        RaceText.scope(uf)
    }
}
