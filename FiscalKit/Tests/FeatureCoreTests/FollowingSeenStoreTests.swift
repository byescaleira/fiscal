import Foundation
import Testing

@testable import FeatureCore

struct FollowingSeenStoreTests {
    @Test func marksAndForgetsPerPerson() throws {
        let suite = "FollowingSeenStoreTests-\(UUID().uuidString)"
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let store = FollowingSeenStore(suiteName: suite)
        let date = Date(timeIntervalSince1970: 1_793_000_000)
        #expect(store.seen("a") == nil)
        store.markSeen(["a", "b"], at: date)
        #expect(store.seen("a") == date)
        store.forget(keeping: ["b"])
        #expect(store.seen("a") == nil)
        #expect(store.seen("b") == date)
        #expect(
            UserDefaults(suiteName: suite)?.dictionary(forKey: FollowingSeenStore.key)?.count == 1)
    }
}
