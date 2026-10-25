import Foundation

public struct Source: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let url: URL?
    public let updatedAt: Date?

    public init(id: String, name: String, url: URL?, updatedAt: Date?) {
        self.id = id
        self.name = name
        self.url = url
        self.updatedAt = updatedAt
    }
}
