public struct Repositories: Sendable {
    public let lens: any LensRepository
    public let follows: any FollowRepository

    public init(lens: any LensRepository, follows: any FollowRepository) {
        self.lens = lens
        self.follows = follows
    }
}
