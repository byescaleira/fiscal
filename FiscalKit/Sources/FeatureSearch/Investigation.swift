import FiscalDomain
import Foundation

public struct Investigation: Codable, Hashable, Identifiable, Sendable {
    public static let pieceLimit = 8

    public let id: UUID
    public var question: String
    public var pieces: [InvestigationPiece]
    public var conclusion: String?
    public var keyNumber: String?
    public var isPinned: Bool
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(), question: String, pieces: [InvestigationPiece] = [],
        conclusion: String? = nil, keyNumber: String? = nil, isPinned: Bool = false,
        createdAt: Date = .now, updatedAt: Date = .now
    ) {
        self.id = id
        self.question = question
        self.pieces = Array(pieces.prefix(Self.pieceLimit))
        self.conclusion = conclusion
        self.keyNumber = keyNumber
        self.isPinned = isPinned
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, question, pieces, conclusion, keyNumber, isPinned, createdAt, updatedAt
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        question = try container.decodeIfPresent(String.self, forKey: .question) ?? ""
        pieces = try container.decodeIfPresent([InvestigationPiece].self, forKey: .pieces) ?? []
        conclusion = try container.decodeIfPresent(String.self, forKey: .conclusion)
        keyNumber = try container.decodeIfPresent(String.self, forKey: .keyNumber)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .distantPast
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
    }

    public var canAdd: Bool { pieces.count < Self.pieceLimit }

    public var isWorthKeeping: Bool {
        !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !pieces.isEmpty
    }

    public func contains(_ piece: InvestigationPiece) -> Bool {
        pieces.contains { $0.id == piece.id }
    }

    public mutating func add(_ piece: InvestigationPiece) {
        guard !contains(piece), canAdd else { return }
        pieces.append(piece)
    }

    public mutating func remove(_ piece: InvestigationPiece) {
        pieces.removeAll { $0.id == piece.id }
    }

    public var title: String {
        let text = question.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty { return text }
        let names = pieces.prefix(3).map(\.title)
        return names.isEmpty
            ? String(appLocalized: "New investigation")
            : names.formatted(.list(type: .and).locale(.app))
    }

    static func ordered(_ list: [Investigation]) -> [Investigation] {
        list.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }
}

extension Investigation {
    init?(saved: SavedInvestigation) {
        let pieces =
            saved.pieces.isEmpty
            ? []
            : (try? PublicDataCoding.decoder().decode(
                [InvestigationPiece].self, from: saved.pieces))
        guard let pieces else { return nil }
        self.init(
            id: saved.id, question: saved.question, pieces: pieces, conclusion: saved.conclusion,
            keyNumber: saved.keyNumber, isPinned: saved.isPinned, createdAt: saved.createdAt,
            updatedAt: saved.updatedAt)
    }

    var saved: SavedInvestigation? {
        guard let data = try? PublicDataCoding.encoder().encode(pieces) else { return nil }
        return SavedInvestigation(
            id: id, question: question, pieces: data, conclusion: conclusion,
            keyNumber: keyNumber, isPinned: isPinned, createdAt: createdAt, updatedAt: updatedAt)
    }
}

public struct DeviceInvestigations: Sendable {
    public static let key = "fiscal.search.investigations"
    public static let legacyKey = "search.investigations"
    private let suiteName: String?

    public init(suiteName: String? = nil) {
        self.suiteName = suiteName
    }

    private var defaults: UserDefaults {
        DeviceDefaults.migrated(suiteName, from: Self.legacyKey, to: Self.key)
    }

    public func load() -> [Investigation] {
        guard let data = defaults.data(forKey: Self.key),
            let list = try? PublicDataCoding.decoder().decode([Investigation].self, from: data)
        else { return [] }
        return list
    }

    public func clear() {
        defaults.removeObject(forKey: Self.key)
    }
}
