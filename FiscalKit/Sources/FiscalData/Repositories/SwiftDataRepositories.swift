import FiscalDomain
import Foundation

struct SwiftDataSupportRepository: SupportRepository {
    let store: FiscalStore

    func support() async throws -> SupportChoice? {
        try await store.support()
    }

    func save(_ support: SupportChoice) async throws {
        try await store.save(support: support)
    }

    func reset() async throws {
        try await store.resetSupport()
    }
}

struct SwiftDataFollowRepository: FollowRepository {
    let store: FiscalStore

    func followed() async throws -> [FollowedPerson] {
        try await store.followed()
    }

    func isFollowing(slug: String) async throws -> Bool {
        try await store.isFollowing(slug: slug)
    }

    func follow(_ card: PersonCard, at date: Date) async throws {
        try await store.follow(card, at: date)
    }

    func unfollow(slug: String) async throws {
        try await store.unfollow(slug: slug)
    }
}

struct SwiftDataLikeRepository: LikeRepository {
    let store: FiscalStore

    func liked() async throws -> [LikedItem] {
        try await store.liked()
    }

    func like(_ item: LikedItem) async throws {
        try await store.like(item)
    }

    func unlike(id: String) async throws {
        try await store.unlike(id: id)
    }

    func reset() async throws {
        try await store.resetLikes()
    }
}
