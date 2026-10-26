import FiscalDomain
import Foundation

public enum SupportedPeople {
    public static func cards(
        for slugs: [String], service: (any PublicDataService)?,
        follows: (any FollowRepository)?
    ) async -> [PersonCard] {
        guard !slugs.isEmpty else { return [] }
        var known: [String: PersonCard] = [:]
        for person in (try? await follows?.followed()) ?? [] where slugs.contains(person.card.slug) {
            known[person.card.slug] = person.card
        }
        if known.count < slugs.count, let people = try? await service?.people() {
            for card in people where slugs.contains(card.slug) && known[card.slug] == nil {
                known[card.slug] = card
            }
        }
        return slugs.compactMap { known[$0] }
    }

    public static func activity(
        for cards: [PersonCard], service: (any PublicDataService)?
    ) async -> [SupportActivity] {
        guard let service, !cards.isEmpty else { return [] }
        let found = await withTaskGroup(of: SupportActivity.self) { group in
            for card in cards {
                group.addTask {
                    let actions = try? await service.actions(slug: card.slug)
                    let hasActions = !(actions?.items.isEmpty ?? true)
                    let profile = hasActions ? nil : try? await service.profile(slug: card.slug)
                    return SupportActivity(
                        slug: card.slug, name: card.name, actions: actions, profile: profile)
                }
            }
            var all: [SupportActivity] = []
            for await item in group { all.append(item) }
            return all
        }
        return cards.compactMap { card in found.first { $0.slug == card.slug } }
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

    public static func names(_ cards: [PersonCard]) -> String {
        cards.map(\.name).formatted(.list(type: .and).locale(.app))
    }
}
