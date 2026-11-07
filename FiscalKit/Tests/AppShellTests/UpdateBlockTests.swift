import FeatureCore
import FiscalDomain
import Foundation
import Testing

@testable import AppShell

private actor RecordingResults: LiveResultsService {
    var followed: [String] = []

    func races() async throws -> [Race] { [] }

    func follow(raceID: String, pushToken: String, environment: PushEnvironment) async throws {
        followed.append(raceID)
    }

    func unfollow(pushToken: String) async throws {}
}

@MainActor
struct UpdateBlockTests {
    private func store(_ state: UpdateState?) throws -> AppReleaseStore {
        let store = AppReleaseStore(
            directory: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString))
        try store.write(AppReleaseCache(simulated: state))
        return store
    }

    @Test func intentsRefuseWhileAnUpdateIsRequired() throws {
        let blocked = try store(.required)
        #expect(blocked.blocks)
        #expect(throws: UpdateRequiredError.self) { try IntentWorkspace.ensureOpen(store: blocked) }
        #expect(throws: UpdateRequiredError.self) { try IntentWorkspace.actions(store: blocked) }
    }

    @Test func intentsRunWhenTheAppIsCurrent() throws {
        let open = try store(nil)
        #expect(!open.blocks)
        try IntentWorkspace.ensureOpen(store: open)
    }

    @Test func theBackgroundRefreshWaitsForTheUpdate() throws {
        #expect(!OfflineDataCenter.refreshesInBackground(store: try store(.required)))
        #expect(OfflineDataCenter.refreshesInBackground(store: try store(.recommended)))
    }

    @Test func raceRegistrationWaitsForTheHoldToRelease() async throws {
        let base = RecordingResults()
        let gate = HoldGate()
        let service = HeldLiveResultsService(base: base, gate: gate)
        await #expect(throws: LiveResultsError.unavailable) {
            try await service.follow(raceID: "br", pushToken: "a", environment: .development)
        }
        gate.release()
        try await service.follow(raceID: "br", pushToken: "a", environment: .development)
        #expect(await base.followed == ["br"])
    }
}
