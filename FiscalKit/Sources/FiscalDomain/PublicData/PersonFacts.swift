import Foundation

public struct PersonFacts: Codable, Hashable, Identifiable, Sendable {
    public struct Guidance: Codable, Hashable, Sendable {
        public let followed: Int
        public let against: Int
        public let other: Int
        public let first: CalendarDay?
        public let last: CalendarDay?

        public init(
            followed: Int, against: Int, other: Int, first: CalendarDay? = nil,
            last: CalendarDay? = nil
        ) {
            self.followed = followed
            self.against = against
            self.other = other
            self.first = first
            self.last = last
        }

        public var total: Int { followed + against + other }

        public static func tally(_ votes: [PersonVote]) -> Guidance? {
            var followed = 0
            var against = 0
            var other = 0
            var days: [CalendarDay] = []
            for vote in votes {
                guard let guidance = vote.partyGuidance.map(Self.key),
                    guidance == "sim" || guidance == "nao"
                else { continue }
                let ballot = Self.key(vote.vote)
                if ballot == guidance {
                    followed += 1
                } else if ballot == "sim" || ballot == "nao" {
                    against += 1
                } else {
                    other += 1
                }
                days.append(vote.date)
            }
            guard followed + against + other > 0 else { return nil }
            return Guidance(
                followed: followed, against: against, other: other, first: days.min(),
                last: days.max())
        }

        public static func key(_ text: String) -> String {
            text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    public let slug: String
    public let house: String?
    public let guidance: Guidance?
    public let checks: Int
    public let themeKeys: [String]

    private enum CodingKeys: String, CodingKey {
        case slug, house, guidance, checks
        case themeKeys = "themes"
    }

    public init(
        slug: String, house: String?, guidance: Guidance?, checks: Int, themes: [Theme]
    ) {
        self.slug = slug
        self.house = house
        self.guidance = guidance
        self.checks = checks
        themeKeys = themes.map(\.rawValue)
    }

    public var id: String { slug }

    public var themes: [Theme] { themeKeys.compactMap(Theme.init(rawValue:)) }

    public var publishesGuidance: Bool { house == House.camara.rawValue }
}

public struct FactIndex: Codable, Hashable, Sendable {
    public let generatedAt: Date?
    public let items: [PersonFacts]
    public let sources: [Source]

    public init(generatedAt: Date?, items: [PersonFacts], sources: [Source]) {
        self.generatedAt = generatedAt
        self.items = items
        self.sources = sources
    }

    public func facts(for slug: String) -> PersonFacts? {
        items.first { $0.slug == slug }
    }
}
