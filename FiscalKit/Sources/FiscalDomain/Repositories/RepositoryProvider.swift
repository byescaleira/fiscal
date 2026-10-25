public protocol RepositoryProvider: Sendable {
    var repositories: Repositories { get }
}
