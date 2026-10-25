#if DEBUG
    import FiscalDomain
    import Foundation

    public struct ShowcasePublicData: PublicDataService {
        public let scenario: PublicDataScenario
        private let now: Date
        private let calendar: Calendar

        public init(
            scenario: PublicDataScenario, now: Date = .now,
            calendar: Calendar = FiscalCalendar.current
        ) {
            self.scenario = scenario
            self.now = now
            self.calendar = calendar
        }

        public static func fromLaunchArguments() -> ShowcasePublicData? {
            PublicDataScenario.fromLaunchArguments().map { ShowcasePublicData(scenario: $0) }
        }

        private var isEmpty: Bool { scenario == .empty }

        private var longText: Bool { scenario == .longNames }

        private var year: Int { calendar.component(.year, from: now) }

        private var sources: [Source] { ShowcaseMoney.sources(now: now) }

        private var everyone: [PersonCard] {
            switch scenario {
            case .empty, .offline, .unavailable: []
            case .normal: ShowcasePeople.regular
            case .longNames: ShowcasePeople.long + ShowcasePeople.regular
            }
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
            guard ShowcaseProfiles.isFederalLegislator(card.office),
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
                    places: isEmpty ? 0 : ShowcasePeople.places().count))
        }

        public func people() async throws -> [PersonCard] {
            try check()
            return everyone.sorted {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
        }

        public func places() async throws -> [Place] {
            try check()
            return isEmpty ? [] : ShowcasePeople.places()
        }

        public func representatives(uf: String) async throws -> PlaceRepresentatives {
            try check()
            return ShowcasePeople.representatives(uf: uf, people: everyone, sources: sources)
        }

        public func profile(slug: String) async throws -> Profile {
            ShowcaseProfiles.profile(for: try person(slug), year: year, sources: sources)
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
            ShowcaseMoney.expenses(for: try legislator(slug), year: year)
        }

        public func checks(slug: String) async throws -> FactCheckList? {
            try check()
            return isEmpty ? nil : ShowcaseChecks.list(for: slug, now: now)
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
