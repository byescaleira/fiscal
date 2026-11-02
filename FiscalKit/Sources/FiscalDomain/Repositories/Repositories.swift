public struct Repositories: Sendable {
    public let support: any SupportRepository
    public let follows: any FollowRepository
    public let investigations: (any InvestigationRepository)?

    public init(
        support: any SupportRepository, follows: any FollowRepository,
        investigations: (any InvestigationRepository)? = nil
    ) {
        self.support = support
        self.follows = follows
        self.investigations = investigations
    }
}
