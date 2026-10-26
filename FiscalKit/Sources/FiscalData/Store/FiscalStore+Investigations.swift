import FiscalDomain
import Foundation
import SwiftData

extension FiscalStore {
    public func investigations() throws -> [SavedInvestigation] {
        let entities = try modelContext.fetch(
            FetchDescriptor<InvestigationEntity>(
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]))
        var seen: Set<String> = []
        return entities.compactMap { entity in
            guard seen.insert(entity.investigationID).inserted else { return nil }
            return entity.saved
        }
    }

    public func save(_ investigation: SavedInvestigation) throws {
        do {
            let existing = try investigationEntities(id: investigation.id)
            if existing.isEmpty {
                modelContext.insert(InvestigationEntity(investigation: investigation))
            } else {
                for entity in existing { entity.update(with: investigation) }
            }
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    public func deleteInvestigation(id: UUID) throws {
        do {
            for entity in try investigationEntities(id: id) { modelContext.delete(entity) }
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    private func investigationEntities(id: UUID) throws -> [InvestigationEntity] {
        let key = id.uuidString
        return try modelContext.fetch(
            FetchDescriptor<InvestigationEntity>(
                predicate: #Predicate { $0.investigationID == key }))
    }
}
