import Foundation

public enum PoliticalStance: String, CaseIterable, Codable, Identifiable, Sendable {
    case preferNotToSay, left, centerLeft, center, centerRight, right

    public var id: String { rawValue }

    public static var scale: [PoliticalStance] {
        [.left, .centerLeft, .center, .centerRight, .right]
    }

    public var title: String {
        switch self {
        case .preferNotToSay: String(appLocalized: "Prefer not to say")
        case .left: String(appLocalized: "Left")
        case .centerLeft: String(appLocalized: "Center-left")
        case .center: String(appLocalized: "Center")
        case .centerRight: String(appLocalized: "Center-right")
        case .right: String(appLocalized: "Right")
        }
    }
}

public struct Lens: Codable, Hashable, Sendable {
    public static let themeRange = 3...5

    public private(set) var themes: [Theme]
    public var stance: PoliticalStance?
    public var artCollection: String?
    public var palette: String?

    public init(
        themes: [Theme] = [], stance: PoliticalStance? = nil, artCollection: String? = nil,
        palette: String? = nil
    ) {
        var unique: [Theme] = []
        for theme in themes where !unique.contains(theme) { unique.append(theme) }
        self.themes = Array(unique.prefix(Self.themeRange.upperBound))
        self.stance = stance
        self.artCollection = artCollection
        self.palette = palette
    }

    public var isComplete: Bool { Self.themeRange.contains(themes.count) }

    public var canAddTheme: Bool { themes.count < Self.themeRange.upperBound }

    public func contains(_ theme: Theme) -> Bool { themes.contains(theme) }

    public mutating func toggle(_ theme: Theme) {
        if let index = themes.firstIndex(of: theme) {
            themes.remove(at: index)
        } else if canAddTheme {
            themes.append(theme)
        }
    }

    public func ordered(_ values: [Theme]) -> [Theme] {
        values.enumerated()
            .sorted { lhs, rhs in
                (rank(of: lhs.element), lhs.offset) < (rank(of: rhs.element), rhs.offset)
            }
            .map(\.element)
    }

    private func rank(of theme: Theme) -> Int {
        themes.firstIndex(of: theme) ?? themes.count
    }
}

extension Lens {
    private enum CodingKeys: String, CodingKey {
        case themes, stance, artCollection, palette
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            themes: try container.decodeIfPresent([Theme].self, forKey: .themes) ?? [],
            stance: try container.decodeIfPresent(PoliticalStance.self, forKey: .stance),
            artCollection: try container.decodeIfPresent(String.self, forKey: .artCollection),
            palette: try container.decodeIfPresent(String.self, forKey: .palette))
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
