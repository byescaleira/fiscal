import Foundation

public struct Item: Identifiable, Hashable, Sendable, Codable {
    public static let minimumTitleLength = 1

    public var id: String
    public var title: String
    public var createdAt: Date

    public init(id: String = UUID().uuidString, title: String, createdAt: Date = .now) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
    }

    public var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var isValid: Bool { trimmedTitle.count >= Self.minimumTitleLength }
}
