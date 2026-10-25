import FiscalDomain
import Foundation

struct SwiftDataLensRepository: LensRepository {
    let store: FiscalStore

    func lens() async throws -> Lens? {
        try await store.lens()
    }

    func save(_ lens: Lens) async throws {
        try await store.save(lens)
    }

    func reset() async throws {
        try await store.resetLens()
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
