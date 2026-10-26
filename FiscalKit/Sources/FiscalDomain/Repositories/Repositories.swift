public struct Repositories: Sendable {
    public let lens: any LensRepository
    public let follows: any FollowRepository
    public let investigations: (any InvestigationRepository)?

    public init(
        lens: any LensRepository, follows: any FollowRepository,
        investigations: (any InvestigationRepository)? = nil
    ) {
        self.lens = lens
        self.follows = follows
        self.investigations = investigations
    }
}
