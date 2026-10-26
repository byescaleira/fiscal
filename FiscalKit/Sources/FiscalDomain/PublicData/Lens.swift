import Foundation

public struct Lens: Codable, Hashable, Sendable {
    public static let themeRange = 3...5
    public static let supportLimit = 5
    public static let suggestedPalette = "graphite"
    public static let suggestedArt = "brasil-agora"

    public static func suggested(supported: [String] = [], prefersNotToSay: Bool = false) -> Lens {
        Lens(
            themes: SupportThemes.suggested([], prefersNotToSay: true), supported: supported,
            prefersNotToSay: prefersNotToSay, artCollection: suggestedArt,
            palette: suggestedPalette)
    }

    public private(set) var themes: [Theme]
    public private(set) var supported: [String]
    public private(set) var prefersNotToSay: Bool
    public var artCollection: String?
    public var palette: String?
    public var icon: String?

    public init(
        themes: [Theme] = [], supported: [String] = [], prefersNotToSay: Bool = false,
        artCollection: String? = nil, palette: String? = nil, icon: String? = nil
    ) {
        self.themes = Array(Self.unique(themes).prefix(Self.themeRange.upperBound))
        let people = prefersNotToSay ? [] : Self.unique(supported)
        self.supported = Array(people.prefix(Self.supportLimit))
        self.prefersNotToSay = prefersNotToSay
        self.artCollection = artCollection
        self.palette = palette
        self.icon = icon
    }

    public var hasChoice: Bool { prefersNotToSay || !supported.isEmpty }

    public var isNeutral: Bool { supported.isEmpty }

    public var isComplete: Bool { hasChoice && Self.themeRange.contains(themes.count) }

    public var canAddTheme: Bool { themes.count < Self.themeRange.upperBound }

    public var canRemoveTheme: Bool { themes.count > Self.themeRange.lowerBound }

    public var canAddSupport: Bool { supported.count < Self.supportLimit }

    public func contains(_ theme: Theme) -> Bool { themes.contains(theme) }

    public func supports(_ slug: String?) -> Bool {
        slug.map(supported.contains) ?? false
    }

    public mutating func toggle(_ theme: Theme) {
        if let index = themes.firstIndex(of: theme) {
            themes.remove(at: index)
        } else if canAddTheme {
            themes.append(theme)
        }
    }

    public mutating func replaceThemes(_ values: [Theme]) {
        themes = Array(Self.unique(values).prefix(Self.themeRange.upperBound))
    }

    public mutating func moveTheme(from source: IndexSet, to destination: Int) {
        let moving = source.filter(themes.indices.contains).map { themes[$0] }
        let target = destination - source.count { $0 < destination }
        var rest = themes.enumerated().filter { !source.contains($0.offset) }.map(\.element)
        rest.insert(contentsOf: moving, at: min(max(target, 0), rest.count))
        themes = rest
    }

    public mutating func moveTheme(_ theme: Theme, by offset: Int) {
        guard let index = themes.firstIndex(of: theme) else { return }
        let target = index + offset
        guard themes.indices.contains(target) else { return }
        themes.swapAt(index, target)
    }

    public mutating func moveTheme(_ theme: Theme, before other: Theme) {
        guard theme != other, let from = themes.firstIndex(of: theme),
            let to = themes.firstIndex(of: other)
        else { return }
        themes.remove(at: from)
        themes.insert(theme, at: to)
    }

    public mutating func toggleSupport(_ slug: String) {
        if let index = supported.firstIndex(of: slug) {
            supported.remove(at: index)
        } else if canAddSupport {
            supported.append(slug)
            prefersNotToSay = false
        }
    }

    public mutating func choosePrefersNotToSay() {
        supported = []
        prefersNotToSay = true
    }

    public func ordered(_ values: [Theme]) -> [Theme] {
        values.enumerated()
            .sorted { lhs, rhs in
                (rank(of: lhs.element), lhs.offset) < (rank(of: rhs.element), rhs.offset)
            }
            .map(\.element)
    }

    public func rank(of theme: Theme) -> Int {
        themes.firstIndex(of: theme) ?? themes.count
    }

    public func supportRank(of slug: String?) -> Int {
        slug.flatMap { supported.firstIndex(of: $0) } ?? supported.count
    }

    private static func unique<Value: Equatable>(_ values: [Value]) -> [Value] {
        var seen: [Value] = []
        for value in values where !seen.contains(value) { seen.append(value) }
        return seen
    }
}

extension Lens {
    private enum CodingKeys: String, CodingKey {
        case themes, supported, prefersNotToSay, artCollection, palette, icon
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            themes: try container.decodeIfPresent([Theme].self, forKey: .themes) ?? [],
            supported: try container.decodeIfPresent([String].self, forKey: .supported) ?? [],
            prefersNotToSay: try container.decodeIfPresent(Bool.self, forKey: .prefersNotToSay)
                ?? false,
            artCollection: try container.decodeIfPresent(String.self, forKey: .artCollection),
            palette: try container.decodeIfPresent(String.self, forKey: .palette),
            icon: try container.decodeIfPresent(String.self, forKey: .icon))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(themes, forKey: .themes)
        try container.encode(supported, forKey: .supported)
        try container.encode(prefersNotToSay, forKey: .prefersNotToSay)
        try container.encodeIfPresent(artCollection, forKey: .artCollection)
        try container.encodeIfPresent(palette, forKey: .palette)
        try container.encodeIfPresent(icon, forKey: .icon)
    }
}

extension Theme {
    public static var setupChoices: [Theme] {
        [
            .health, .education, .security, .economy, .taxes, .environment,
            .social, .rights, .politics, .city, .countryside, .women,
        ]
    }

    public static var moreChoices: [Theme] {
        allCases.filter { !setupChoices.contains($0) }
    }

    public static var neutralOrder: [Theme] { setupChoices + moreChoices }

    public var coverage: String {
        switch self {
        case .health: String(appLocalized: "SUS, hospitals, medicines and vaccines")
        case .education: String(appLocalized: "Schools, universities and teachers")
        case .security: String(appLocalized: "Police, crime and prisons")
        case .economy: String(appLocalized: "Jobs, income, prices and companies")
        case .taxes: String(appLocalized: "Taxes, the budget and how public money is spent")
        case .environment: String(appLocalized: "Forests, climate, water and animals")
        case .city: String(appLocalized: "Housing, sanitation and urban life")
        case .transport: String(appLocalized: "Roads, traffic and public transport")
        case .social: String(appLocalized: "Bolsa Família, pensions and social aid")
        case .women: String(appLocalized: "Violence against women, work and care")
        case .countryside: String(appLocalized: "Agribusiness, family farming and land")
        case .culture: String(appLocalized: "Culture, sports and leisure")
        case .rights: String(appLocalized: "Human rights, minorities and equality")
        case .consumer: String(appLocalized: "Consumer rights, banks and services")
        case .technology: String(appLocalized: "Internet, data, science and innovation")
        case .politics: String(appLocalized: "Elections, parties and how Congress works")
        case .tributes: String(appLocalized: "Honors, commemorative dates and names")
        }
    }
}

public struct FollowedPerson: Codable, Hashable, Identifiable, Sendable {
    public let card: PersonCard
    public let followedAt: Date

    public init(card: PersonCard, followedAt: Date) {
        self.card = card
        self.followedAt = followedAt
    }

    public var id: String { card.slug }
}
