public struct Repositories: Sendable {
    public let items: any ItemRepository

    public init(items: any ItemRepository) {
        self.items = items
    }
}
