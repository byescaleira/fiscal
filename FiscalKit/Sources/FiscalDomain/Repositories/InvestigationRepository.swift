import Foundation

public struct SavedInvestigation: Hashable, Identifiable, Sendable {
    public let id: UUID
    public var question: String
    public var pieces: Data
    public var conclusion: String?
    public var keyNumber: String?
    public var isPinned: Bool
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID, question: String, pieces: Data, conclusion: String?, keyNumber: String?,
        isPinned: Bool, createdAt: Date, updatedAt: Date
    ) {
        self.id = id
        self.question = question
        self.pieces = pieces
        self.conclusion = conclusion
        self.keyNumber = keyNumber
        self.isPinned = isPinned
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public protocol InvestigationRepository: Sendable {
    func investigations() async throws -> [SavedInvestigation]
    func save(_ investigation: SavedInvestigation) async throws
    func delete(id: UUID) async throws
    func syncsWithCloud() async -> Bool
}
