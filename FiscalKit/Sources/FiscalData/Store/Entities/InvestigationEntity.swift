import FiscalDomain
import Foundation
import SwiftData

@Model
public class InvestigationEntity {
    #Index<InvestigationEntity>([\.investigationID], [\.updatedAt])
    public var investigationID: String = ""
    public var question: String = ""
    public var pieces: Data?
    public var conclusion: String?
    public var keyNumber: String?
    public var isPinned: Bool = false
    public var createdAt: Date = Date.distantPast
    public var updatedAt: Date = Date.distantPast

    public init(investigation: SavedInvestigation) {
        investigationID = investigation.id.uuidString
        createdAt = investigation.createdAt
        update(with: investigation)
    }

    func update(with investigation: SavedInvestigation) {
        question = investigation.question
        pieces = investigation.pieces
        conclusion = investigation.conclusion
        keyNumber = investigation.keyNumber
        isPinned = investigation.isPinned
        updatedAt = investigation.updatedAt
    }

    var saved: SavedInvestigation? {
        guard let id = UUID(uuidString: investigationID) else { return nil }
        return SavedInvestigation(
            id: id, question: question, pieces: pieces ?? Data(), conclusion: conclusion,
            keyNumber: keyNumber, isPinned: isPinned, createdAt: createdAt, updatedAt: updatedAt)
    }
}
