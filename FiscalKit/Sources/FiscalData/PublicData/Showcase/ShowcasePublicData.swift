#if DEBUG
    import FiscalDomain
    import Foundation

    public struct ShowcasePublicData: PublicDataService {
        public let scenario: PublicDataScenario
        private let now: Date
        private let calendar: Calendar
        private let roster: ShowcaseRoster
        private let series: ShowcaseIndicators

        public init(
            scenario: PublicDataScenario, now: Date = .now,
            calendar: Calendar = FiscalCalendar.current, roster: ShowcaseRoster = .curated,
            indicators: ShowcaseIndicators = .none
        ) {
            self.scenario = scenario
            self.now = now
            self.calendar = calendar
            self.roster = roster
            series = indicators
        }

        public static func fromLaunchArguments(
            roster: ShowcaseRoster = .curated, indicators: ShowcaseIndicators = .none
        ) -> ShowcasePublicData? {
            PublicDataScenario.fromLaunchArguments().map {
                ShowcasePublicData(scenario: $0, roster: roster, indicators: indicators)
            }
        }

        private var isEmpty: Bool { scenario == .empty }

        private var longText: Bool { scenario == .longNames }

        private var year: Int { calendar.component(.year, from: now) }

        private var sources: [Source] { ShowcaseMoney.sources(now: now) }

        private var curated: [PersonCard] {
            switch scenario {
            case .empty, .offline, .unavailable: []
            case .normal: ShowcasePeople.regular
            case .longNames: ShowcasePeople.long + ShowcasePeople.regular
            }
        }

        private var everyone: [PersonCard] {
            isEmpty || curated.isEmpty
                ? curated : ShowcasePeople.merged(curated, with: roster.people())
        }

        private var municipalSources: [Source] {
            [
                Source(
                    id: Source.municipalElectionID, name: "Tribunal Superior Eleitoral",
                    url: URL(string: "https://dadosabertos.tse.jus.br"),
                    updatedAt: now.addingTimeInterval(-3 * 3_600))
            ]
        }

        private func check() throws {
            switch scenario {
            case .offline: throw PublicDataError.offline
            case .unavailable: throw PublicDataError.unavailable
            case .normal, .empty, .longNames: return
            }
        }

        private func person(_ slug: String) throws -> PersonCard {
            try check()
            guard let card = everyone.first(where: { $0.slug == slug }) else {
                throw PublicDataError.notFound
            }
            return card
        }

        private func legislator(_ slug: String) throws -> PersonCard {
            let card = try person(slug)
            guard curated.contains(where: { $0.slug == slug }),
                ShowcaseProfiles.isFederalLegislator(card.office),
                card.status != .electedAwaiting
            else { throw PublicDataError.notFound }
            return card
        }

        public func meta() async throws -> PublicMeta {
            try check()
            let people = everyone
            return PublicMeta(
                generatedAt: now.addingTimeInterval(-3 * 3_600), sources: sources,
                counts: PublicMeta.Counts(
                    people: people.count, federal: people.filter(\.office.isFederal).count,
                    state: people.filter { !$0.office.isFederal }.count,
                    places: isEmpty ? 0 : ShowcasePeople.places(cities: roster.places()).count))
        }

        public func people() async throws -> [PersonCard] {
            try check()
            return everyone.sorted {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
        }

        public func places() async throws -> [Place] {
            try check()
            return isEmpty ? [] : ShowcasePeople.places(cities: roster.places())
        }

        public func representatives(uf: String) async throws -> PlaceRepresentatives {
            try check()
            return ShowcasePeople.representatives(uf: uf, people: everyone, sources: sources)
        }

        public func cityRepresentatives(code: String) async throws -> PlaceRepresentatives? {
            try check()
            guard !isEmpty, let city = roster.city(code) else { return nil }
            let hall = city.officials.filter { $0.office != .cityCouncilor }
                .sorted { $0.office == .mayor && $1.office != .mayor }
            let extra =
                longText && !city.officials.isEmpty
                ? ShowcaseRoster.cards(ShowcasePeople.longCouncil, in: city.place)
                    .map { card in
                        PersonCard(
                            slug: "teste-\(card.slug)", name: card.name, office: card.office,
                            uf: card.uf, party: card.party, photo: nil, status: card.status)
                    } : []
            let council = (city.officials.filter { $0.office == .cityCouncilor } + extra)
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            let groups = [
                RepresentativeGroup(
                    level: .city, office: .mayor, title: "Prefeitura", people: hall),
                RepresentativeGroup(
                    level: .city, office: .cityCouncilor, title: "Câmara Municipal",
                    people: council),
            ]
            return PlaceRepresentatives(
                code: city.place.code, uf: city.place.uf, name: city.place.name,
                groups: groups.filter { !$0.people.isEmpty }, note: city.note,
                sources: municipalSources)
        }

        public func profile(slug: String) async throws -> Profile {
            try check()
            if let card = curated.first(where: { $0.slug == slug }) {
                return ShowcaseProfiles.profile(for: card, year: year, sources: sources)
            }
            if let card = everyone.first(where: { $0.slug == slug }) {
                return ShowcaseProfiles.minimal(for: card, sources: sources)
            }
            guard !isEmpty, let card = municipal(slug) else { throw PublicDataError.notFound }
            return ShowcaseProfiles.minimal(for: card, sources: municipalSources)
        }

        private func municipal(_ slug: String) -> PersonCard? {
            if let card = roster.official(slug: slug) { return card }
            guard longText, slug.hasPrefix("teste-"),
                let code = ShowcaseRoster.code(in: slug), let city = roster.city(code)
            else { return nil }
            return ShowcaseRoster.cards(ShowcasePeople.longCouncil, in: city.place)
                .first { "teste-\($0.slug)" == slug }
                .map {
                    PersonCard(
                        slug: slug, name: $0.name, office: $0.office, uf: $0.uf, party: $0.party,
                        photo: nil, status: $0.status)
                }
        }

        public func votes(slug: String, year: Int) async throws -> PublicList<PersonVote> {
            ShowcaseVotes.personVotes(for: try legislator(slug), now: now, longText: longText)
        }

        public func proposals(slug: String, year: Int) async throws -> PublicList<Proposal> {
            ShowcaseVotes.proposals(for: try legislator(slug), year: year)
        }

        public func speeches(slug: String, year: Int) async throws -> PublicList<Speech> {
            ShowcaseVotes.speeches(for: try legislator(slug), now: now)
        }

        public func expenses(slug: String, year: Int) async throws -> ExpenseList {
            ShowcaseExpenses.list(
                for: try legislator(slug), year: year, now: now, calendar: calendar,
                longText: longText)
        }

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
            return isEmpty ? [] : ShowcaseVotes.recent(now: now, longText: longText)
        }

        public func vote(id: String) async throws -> VoteDetail {
            try check()
            guard !isEmpty,
                let detail = ShowcaseVotes.detail(
                    id: id, now: now, people: everyone, sources: sources, longText: longText)
            else { throw PublicDataError.notFound }
            return detail
        }

        public func agenda() async throws -> Agenda {
            try check()
            return ShowcaseVotes.agenda(now: now, empty: isEmpty)
        }

        public func money() async throws -> MoneyOverview {
            try check()
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

        public func today() async throws -> TodayDigest {
            try check()
            let votes = isEmpty ? [] : ShowcaseVotes.recent(now: now, longText: longText)
            return isEmpty
                ? TodayDigest(
                    date: CalendarDay(now, calendar: calendar), events: [], sources: sources)
                : ShowcaseMoney.today(now: now, votes: votes, sources: sources)
        }
    }
#endif
