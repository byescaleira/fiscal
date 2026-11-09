public protocol RepositoryProvider: Sendable {
    var repositories: Repositories { get }
    var changes: any StorageChangeFeed { get }
}

extension RepositoryProvider {
    public var changes: any StorageChangeFeed { SilentChangeFeed() }
}
