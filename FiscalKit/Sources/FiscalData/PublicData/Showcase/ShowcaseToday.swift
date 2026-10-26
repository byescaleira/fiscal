#if DEBUG
    import FiscalDomain
    import Foundation

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
