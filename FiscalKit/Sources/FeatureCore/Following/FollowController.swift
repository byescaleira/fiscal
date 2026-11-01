import FiscalDomain
import Foundation
import Observation
import SwiftUI

@MainActor @Observable
public final class FollowingBadge {
    public var count = 0

    public init() {}
}

@MainActor @Observable
public final class FollowController {
    public private(set) var followed: Set<String> = []
    public var error: FiscalError?
    @ObservationIgnored private let follows: (any FollowRepository)?
    @ObservationIgnored private let people: @Sendable () async throws -> [PersonCard]
    @ObservationIgnored private let now: @Sendable () -> Date

    public init(
        follows: (any FollowRepository)?,
        people: @escaping @Sendable () async throws -> [PersonCard] = { [] },
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.follows = follows
        self.people = people
        self.now = now
    }

    public func isFollowing(_ slug: String) -> Bool {
        followed.contains(slug)
    }

    public func reload() async {
        guard let follows, let list = try? await follows.followed() else { return }
        followed = Set(list.map(\.card.slug))
    }

    @discardableResult
    public func toggle(_ card: PersonCard) async -> Bool {
        guard let follows else { return isFollowing(card.slug) }
        let wasFollowing = isFollowing(card.slug)
        do {
            if wasFollowing {
                try await follows.unfollow(slug: card.slug)
                followed.remove(card.slug)
            } else {
                try await follows.follow(card, at: now())
                followed.insert(card.slug)
            }
        } catch {
            self.error = .onSave
        }
        return isFollowing(card.slug)
    }

    @discardableResult
    public func toggle(slug: String) async -> Bool {
        guard let card = try? await people().first(where: { $0.slug == slug }) else {
            error = .onSave
            return isFollowing(slug)
        }
        return await toggle(card)
    }
}
