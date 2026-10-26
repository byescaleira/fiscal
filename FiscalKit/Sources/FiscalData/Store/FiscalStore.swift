import FiscalDomain
import Foundation
import SwiftData

@ModelActor
public actor FiscalStore {
    public func lens() throws -> Lens? {
        try lensEntity()?.lens
    }

    public func save(_ lens: Lens, at date: Date = .now) throws {
        do {
            if let entity = try lensEntity() {
                entity.update(with: lens, at: date)
            } else {
                modelContext.insert(LensEntity(lens: lens, updatedAt: date))
            }
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    public func resetLens() throws {
        do {
            try modelContext.delete(model: LensEntity.self)
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    public func followed() throws -> [FollowedPerson] {
        let entities = try modelContext.fetch(
            FetchDescriptor<FollowEntity>(
                sortBy: [SortDescriptor(\.followedAt), SortDescriptor(\.slug)]))
        var seen: Set<String> = []
        return entities.compactMap { entity in
            guard seen.insert(entity.slug).inserted else { return nil }
            return entity.followed
        }
        .sorted { $0.card.name.localizedStandardCompare($1.card.name) == .orderedAscending }
    }

    public func isFollowing(slug: String) throws -> Bool {
        var descriptor = FetchDescriptor<FollowEntity>(predicate: #Predicate { $0.slug == slug })
        descriptor.fetchLimit = 1
        return try modelContext.fetchCount(descriptor) > 0
    }

    public func follow(_ card: PersonCard, at date: Date) throws {
        let slug = card.slug
        do {
            let existing = try modelContext.fetch(
                FetchDescriptor<FollowEntity>(predicate: #Predicate { $0.slug == slug }))
            if existing.isEmpty {
                modelContext.insert(FollowEntity(card: card, followedAt: date))
            } else {
                for entity in existing { entity.update(with: card) }
            }
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    public func unfollow(slug: String) throws {
        do {
            let existing = try modelContext.fetch(
                FetchDescriptor<FollowEntity>(predicate: #Predicate { $0.slug == slug }))
            for entity in existing { modelContext.delete(entity) }
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    private func lensEntity() throws -> LensEntity? {
        var descriptor = FetchDescriptor<LensEntity>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}
