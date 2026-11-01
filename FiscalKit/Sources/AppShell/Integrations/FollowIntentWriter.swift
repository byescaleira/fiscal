import FeatureCore
import FiscalDomain
import Foundation

struct FollowIntentWriter: Sendable {
    let store: AppReleaseStore
    let people: @Sendable ([String]) async throws -> [PersonCard]
    let follows: @Sendable () async throws -> any FollowRepository
    var widget: @MainActor @Sendable (_ unfollowed: String?) -> Void = {
        FollowingWidget.refresh(unfollowed: $0)
    }

    func follow(slug: String, at date: Date = .now) async throws -> PersonCard {
        try IntentWorkspace.ensureOpen(store: store)
        let card: PersonCard?
        do {
            card = try await people([slug]).first
        } catch {
            throw IntegrationError.unavailable
        }
        guard let card else { throw IntegrationError.unavailable }
        try await follows().follow(card, at: date)
        await widget(nil)
        return card
    }

    func unfollow(slug: String) async throws {
        try IntentWorkspace.ensureOpen(store: store)
        try await follows().unfollow(slug: slug)
        await widget(slug)
    }
}

extension FollowIntentWriter {
    @MainActor
    static func live(store: AppReleaseStore = .shared) throws -> FollowIntentWriter {
        let actions = try IntentWorkspace.actions(store: store)
        return FollowIntentWriter(
            store: store,
            people: { try await actions.people(slugs: $0) },
            follows: {
                try await FiscalServices.shared.database(
                    cloudSync: FiscalServices.launchCloudSync
                ).repositories.follows
            })
    }
}
