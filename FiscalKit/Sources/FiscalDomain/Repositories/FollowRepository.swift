import Foundation

public protocol FollowRepository: Sendable {
    func followed() async throws -> [FollowedPerson]
    func isFollowing(slug: String) async throws -> Bool
    func follow(_ card: PersonCard, at date: Date) async throws
    func unfollow(slug: String) async throws
}
