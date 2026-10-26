#if DEBUG
    import FiscalDomain
    import Foundation

    extension ShowcasePublicData {
        public func checks(slug: String) async throws -> FactCheckList? {
            try check()
            return isEmpty ? nil : ShowcaseChecks.list(for: slug, now: now)
        }

        public func actions(slug: String) async throws -> ActionList? {
            guard let card = try? legislator(slug) else {
                try check()
                return nil
            }
            return ShowcaseWeight.actions(
                for: card, now: now, longText: longText, calendar: calendar)
        }

        public func highlights() async throws -> HighlightList? {
            try check()
            return isEmpty
                ? nil : ShowcaseWeight.highlights(now: now, longText: longText, sources: sources)
        }

        public func weightMethod() async throws -> WeightMethod? {
            try check()
            return ShowcaseWeight.method(sources: sources)
        }

        public func recentVotes() async throws -> [VoteSummary] {
            try check()
            return isEmpty ? [] : recent
        }

        var recent: [VoteSummary] {
            guard let real: [VoteSummary] = real(PublicDataPath.recentVotes) else {
                return ShowcaseVotes.recent(now: now, longText: longText)
            }
            return longText ? ShowcaseVotes.recent(now: now, longText: true) + real : real
        }

        public func vote(id: String) async throws -> VoteDetail {
            try check()
            if let real: VoteDetail = real(PublicDataPath.vote(id: id)) { return real }
            guard !isEmpty,
                let detail = ShowcaseVotes.detail(
                    id: id, now: now, people: everyone, sources: sources, longText: longText)
            else { throw PublicDataError.notFound }
            return detail
        }

        public func agenda() async throws -> Agenda {
            try check()
            if let real: Agenda = real(PublicDataPath.agenda),
                real.houses.contains(where: { !$0.items.isEmpty })
            {
                return Agenda(date: CalendarDay(now, calendar: calendar), houses: real.houses)
            }
            return ShowcaseVotes.agenda(now: now, empty: isEmpty)
        }

        public func money() async throws -> MoneyOverview {
            try check()
            if let real: MoneyOverview = real(PublicDataPath.money) { return real }
            return ShowcaseMoney.overview(year: year, empty: isEmpty, sources: sources)
        }

        public func indicators() async throws -> IndicatorCatalog? {
            try check()
            return isEmpty ? nil : series.catalog()
        }

        public func indicator(id: String) async throws -> Indicator? {
            try check()
            return isEmpty ? nil : series.indicator(id: id)
        }

        public func context(slug: String) async throws -> PersonContext? {
            try check()
            guard !isEmpty, let card = everyone.first(where: { $0.slug == slug }) ?? municipal(slug)
            else { return nil }
            return series.context(for: card)
        }
    }
#endif
