import FiscalDomain
import Foundation

public enum SupportedPeople {
    public static func cards(
        for slugs: [String], service: (any PublicDataService)?,
        follows: (any FollowRepository)?
    ) async -> [PersonCard] {
        guard !slugs.isEmpty else { return [] }
        var known: [String: PersonCard] = [:]
        for person in (try? await follows?.followed()) ?? [] where slugs.contains(person.card.slug)
        {
            known[person.card.slug] = person.card
        }
        if known.count < slugs.count, let people = try? await service?.people() {
            for card in people where slugs.contains(card.slug) && known[card.slug] == nil {
                known[card.slug] = card
            }
        }
        return slugs.compactMap { known[$0] }
    }

    public static func follow(
        _ cards: [PersonCard], in follows: (any FollowRepository)?, at date: Date = .now
    ) async {
        guard let follows else { return }
        for card in cards {
            if (try? await follows.isFollowing(slug: card.slug)) == true { continue }
            try? await follows.follow(card, at: date)
        }
    }
}
