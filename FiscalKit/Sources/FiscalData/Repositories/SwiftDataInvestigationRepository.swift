import CloudKit
import FiscalDomain
import Foundation

struct SwiftDataInvestigationRepository: InvestigationRepository {
    let store: FiscalStore
    let cloudIdentifier: String?

    func investigations() async throws -> [SavedInvestigation] {
        try await store.investigations()
    }

    func save(_ investigation: SavedInvestigation) async throws {
        try await store.save(investigation)
    }

    func delete(id: UUID) async throws {
        try await store.deleteInvestigation(id: id)
    }

    func syncsWithCloud() async -> Bool {
        guard let cloudIdentifier else { return false }
        let status = try? await CKContainer(identifier: cloudIdentifier).accountStatus()
        return status == .available
    }
}
