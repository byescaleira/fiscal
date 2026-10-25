#if DEBUG
    import FiscalDomain
    import Foundation

    public actor ShowcaseLensRepository: LensRepository {
        public static let launchKey = "FiscalLensScenario"
        private var current: Lens?

        public init(stance: PoliticalStance?) {
            current = stance.map { Lens(themes: Self.themes(for: $0), stance: $0) }
        }

        public static func fromLaunchArguments(_ defaults: UserDefaults = .standard)
            -> ShowcaseLensRepository?
        {
            guard let name = defaults.string(forKey: launchKey) else { return nil }
            if name == "none" { return ShowcaseLensRepository(stance: nil) }
            return PoliticalStance(rawValue: name).map(ShowcaseLensRepository.init(stance:))
        }

        public static func themes(for stance: PoliticalStance) -> [Theme] {
            switch stance.effective {
            case .right: [.taxes, .security, .politics]
            case .centerRight: [.economy, .taxes, .security]
            case .center: [.health, .education, .economy]
            case .centerLeft: [.health, .education, .social]
            case .left: [.social, .environment, .rights]
            case .impartial, .preferNotToSay: []
            }
        }

        public func lens() async throws -> Lens? { current }

        public func save(_ lens: Lens) async throws { current = lens }

        public func reset() async throws { current = nil }
    }

    public actor ShowcaseFollowRepository: FollowRepository {
        public static let launchKey = "FiscalFollowScenario"
        private var people: [FollowedPerson]

        public init(scenario: PublicDataScenario, now: Date = .now) {
            let slugs = [
                "tabata-amaral", "nikolas-ferreira", "damares-alves", "humberto-costa",
                "tarcisio-de-freitas",
            ]
            let regular = slugs.compactMap { slug in
                ShowcasePeople.regular.first { $0.slug == slug }
            }
            let cards: [PersonCard] =
                switch scenario {
                case .normal: regular
                case .longNames: Array(ShowcasePeople.long.prefix(2)) + regular.prefix(2)
                case .empty, .offline, .unavailable: []
                }
            people = cards.map { FollowedPerson(card: $0, followedAt: now) }
        }

        public static func fromLaunchArguments(_ defaults: UserDefaults = .standard)
            -> ShowcaseFollowRepository?
        {
            PublicDataScenario.named(defaults.string(forKey: launchKey))
                .map { ShowcaseFollowRepository(scenario: $0) }
        }

        public func followed() async throws -> [FollowedPerson] { people }

        public func isFollowing(slug: String) async throws -> Bool {
            people.contains { $0.card.slug == slug }
        }

        public func follow(_ card: PersonCard, at date: Date) async throws {
            guard !people.contains(where: { $0.card.slug == card.slug }) else { return }
            people.append(FollowedPerson(card: card, followedAt: date))
        }

        public func unfollow(slug: String) async throws {
            people.removeAll { $0.card.slug == slug }
        }
    }
#endif
