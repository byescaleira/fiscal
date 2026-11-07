import FiscalDomain
import Foundation
import SwiftData

extension FiscalStore {
    public func liked() throws -> [LikedItem] {
        let entities = try modelContext.fetch(
            FetchDescriptor<LikeEntity>(
                sortBy: [SortDescriptor(\.likedAt, order: .reverse), SortDescriptor(\.itemID)]))
        var seen: Set<String> = []
        return entities.compactMap { entity in
            guard seen.insert(entity.itemID).inserted else { return nil }
            return entity.liked
        }
    }

    public func like(_ item: LikedItem) throws {
        let id = item.id
        do {
            let existing = try modelContext.fetch(
                FetchDescriptor<LikeEntity>(predicate: #Predicate { $0.itemID == id }))
            if existing.isEmpty {
                modelContext.insert(LikeEntity(item: item))
            } else {
                for entity in existing { entity.update(with: item) }
            }
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    public func unlike(id: String) throws {
        do {
            let existing = try modelContext.fetch(
                FetchDescriptor<LikeEntity>(predicate: #Predicate { $0.itemID == id }))
            for entity in existing { modelContext.delete(entity) }
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    public func resetLikes() throws {
        do {
            try modelContext.delete(model: LikeEntity.self)
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }
}
