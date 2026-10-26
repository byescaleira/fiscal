#if DEBUG
    import FiscalDomain
    import Foundation

    extension ShowcasePublicData {
        public func facts() async throws -> FactIndex? {
            try check()
            if let real: FactIndex = real(PublicDataPath.facts) { return real }
            guard !isEmpty else { return nil }
            let items = curated.filter { card in
                ShowcaseProfiles.isFederalLegislator(card.office) && card.status != .electedAwaiting
            }
            .map { card in
                let votes = ShowcaseVotes.personVotes(for: card, now: now, longText: longText).items
                let house: House = card.office == .senator ? .senado : .camara
                let profile = ShowcaseProfiles.profile(for: card, year: year, sources: sources)
                return PersonFacts(
                    slug: card.slug, house: house.rawValue,
                    guidance: PersonFacts.Guidance.tally(votes),
                    checks: ShowcaseChecks.list(for: card.slug, now: now)?.items.count ?? 0,
                    themes: profile.themes.sorted { $0.proposals > $1.proposals }.prefix(3)
                        .map(\.key))
            }
            return FactIndex(
                generatedAt: now.addingTimeInterval(-3 * 3_600), items: items, sources: sources)
        }
    }
#endif
