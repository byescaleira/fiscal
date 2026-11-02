import Foundation

public struct FollowedPerson: Codable, Hashable, Identifiable, Sendable {
    public let card: PersonCard
    public let followedAt: Date

    public init(card: PersonCard, followedAt: Date) {
        self.card = card
        self.followedAt = followedAt
    }

    public var id: String { card.slug }
}
