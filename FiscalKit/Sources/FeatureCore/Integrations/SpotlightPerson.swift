import FiscalDomain
import Foundation

public struct SpotlightPerson: Hashable, Identifiable, Sendable {
    public static let domain = "fiscal.person"

    public let id: String
    public let title: String
    public let detail: String
    public let keywords: [String]
    public let url: URL?

    public init(_ card: PersonCard) {
        id = card.slug
        title = card.name
        let place = card.uf.lowercased() == "br" ? nil : card.uf.uppercased(with: .app)
        detail = ([card.office.title, card.party] + [place].compactMap(\.self))
            .joined(separator: " · ")
        keywords = [
            card.office.title, card.party, place, place.map { _ in HomePlace.name(of: card.uf) },
        ]
        .compactMap(\.self)
        url = IntegrationLink.person(card.slug)
    }

    public static func entries(followed: [PersonCard], recent: [PersonCard]) -> [SpotlightPerson] {
        var seen = Set<String>()
        return (followed + recent).compactMap { card in
            guard !card.slug.isEmpty, seen.insert(card.slug).inserted else { return nil }
            return SpotlightPerson(card)
        }
    }

    public static func url(forIdentifier identifier: String) -> URL? {
        IntegrationLink.person(identifier)
    }
}

public struct RecentPeople {
    public static let key = "fiscal.integrations.recentPeople"
    public static let limit = 20

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var slugs: [String] {
        defaults.stringArray(forKey: Self.key) ?? []
    }

    @discardableResult
    public func record(_ slug: String) -> Bool {
        guard !slug.isEmpty else { return false }
        let current = slugs
        let updated = Array(([slug] + current.filter { $0 != slug }).prefix(Self.limit))
        guard updated != current else { return false }
        defaults.set(updated, forKey: Self.key)
        return true
    }

    public func clear() {
        defaults.removeObject(forKey: Self.key)
    }

    public static func personSlugs(in routes: [Route]) -> [String] {
        routes.compactMap { route in
            if case .person(let slug) = route { return slug }
            return nil
        }
    }
}
