import FiscalDomain

struct SwiftDataItemRepository: ItemRepository {
    let store: FiscalStore

    func items() async throws -> [Item] {
        try await store.items()
    }

    func item(id: String) async throws -> Item? {
        try await store.item(id: id)
    }

    func save(_ item: Item) async throws {
        try await store.save(item)
    }

    func delete(id: String) async throws {
        try await store.removeItem(id: id)
    }
}
