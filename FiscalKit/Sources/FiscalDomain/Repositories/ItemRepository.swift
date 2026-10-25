public protocol ItemRepository: Sendable {
    func items() async throws -> [Item]
    func item(id: String) async throws -> Item?
    func save(_ item: Item) async throws
    func delete(id: String) async throws
}
