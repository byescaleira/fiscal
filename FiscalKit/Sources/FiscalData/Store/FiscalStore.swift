import FiscalDomain
import Foundation
import SwiftData

@ModelActor
public actor FiscalStore {
    public func items() throws -> [Item] {
        try modelContext.fetch(
            FetchDescriptor<ItemEntity>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse), SortDescriptor(\.id)])
        )
        .map(\.item)
    }

    public func item(id: String) throws -> Item? {
        var descriptor = FetchDescriptor<ItemEntity>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 2
        let values = try modelContext.fetch(descriptor)
        guard values.count <= 1 else {
            throw FiscalError.persistence(
                String(appLocalized: "Some records in storage have conflicting IDs."))
        }
        return values.first?.item
    }

    public func save(_ item: Item) throws {
        guard item.isValid else { throw FiscalError.onSave }
        let id = item.id
        do {
            let descriptor = FetchDescriptor<ItemEntity>(predicate: #Predicate { $0.id == id })
            if let entity = try modelContext.fetch(descriptor).first {
                entity.title = item.trimmedTitle
            } else {
                modelContext.insert(
                    ItemEntity(id: id, title: item.trimmedTitle, createdAt: item.createdAt))
            }
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    public func removeItem(id: String) throws {
        do {
            let descriptor = FetchDescriptor<ItemEntity>(predicate: #Predicate { $0.id == id })
            guard let entity = try modelContext.fetch(descriptor).first else {
                throw FiscalError.missingRecord
            }
            modelContext.delete(entity)
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }
}
