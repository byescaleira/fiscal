import FiscalDomain
import Foundation

public struct Investigation: Codable, Hashable, Identifiable, Sendable {
    public static let pieceLimit = 8

    public let id: UUID
    public var question: String
    public var pieces: [InvestigationPiece]
    public var conclusion: String?
    public var keyNumber: String?
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(), question: String, pieces: [InvestigationPiece] = [],
        conclusion: String? = nil, keyNumber: String? = nil, createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.question = question
        self.pieces = Array(pieces.prefix(Self.pieceLimit))
        self.conclusion = conclusion
        self.keyNumber = keyNumber
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var canAdd: Bool { pieces.count < Self.pieceLimit }

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
}

public protocol InvestigationStore: Sendable {
    func load() -> [Investigation]
    func save(_ investigations: [Investigation])
}

public struct DeviceInvestigations: InvestigationStore, @unchecked Sendable {
    public static let key = "search.investigations"
    public static let limit = 30
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> [Investigation] {
        guard let data = defaults.data(forKey: Self.key),
            let list = try? PublicDataCoding.decoder().decode([Investigation].self, from: data)
        else { return [] }
        return list
    }

    public func save(_ investigations: [Investigation]) {
        let list = Array(investigations.prefix(Self.limit))
        guard !list.isEmpty, let data = try? PublicDataCoding.encoder().encode(list) else {
            defaults.removeObject(forKey: Self.key)
            return
        }
        defaults.set(data, forKey: Self.key)
    }
}
