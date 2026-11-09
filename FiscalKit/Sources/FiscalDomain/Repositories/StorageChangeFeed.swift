public struct StorageChange: Hashable, Sendable {
    public let isRemote: Bool

    public init(isRemote: Bool) {
        self.isRemote = isRemote
    }

    public static let local = StorageChange(isRemote: false)
    public static let remote = StorageChange(isRemote: true)
}

public protocol StorageChangeFeed: Sendable {
    func changes() -> AsyncStream<StorageChange>
}

public struct SilentChangeFeed: StorageChangeFeed {
    public init() {}

    public func changes() -> AsyncStream<StorageChange> {
        AsyncStream { $0.finish() }
    }
}
