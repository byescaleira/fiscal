public struct Repositories: Sendable {
    public let lens: any LensRepository
    public let support: any SupportRepository
    public let follows: any FollowRepository
    public let investigations: (any InvestigationRepository)?

    public init(
        lens: any LensRepository, support: any SupportRepository, follows: any FollowRepository,
        investigations: (any InvestigationRepository)? = nil
    ) {
        self.lens = lens
        self.support = support
        self.follows = follows
        self.investigations = investigations
    }
}
