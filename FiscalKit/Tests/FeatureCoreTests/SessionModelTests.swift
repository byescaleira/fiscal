import FiscalData
import FiscalDomain
import Foundation
import Testing

@testable import FeatureCore

private struct ManualFeed: StorageChangeFeed {
    private let stream: AsyncStream<StorageChange>
    private let continuation: AsyncStream<StorageChange>.Continuation

    init() {
        (stream, continuation) = AsyncStream.makeStream(of: StorageChange.self)
    }

    func changes() -> AsyncStream<StorageChange> {
        stream
    }

    func send(_ change: StorageChange) {
        continuation.yield(change)
    }

    func finish() {
        continuation.finish()
    }
}

@MainActor
struct SessionModelTests {
    private func session(_ feed: ManualFeed) throws -> SessionModel {
        SessionModel(
            repositories: try FiscalDatabase.open(inMemory: true).repositories, changes: feed,
            coalescing: .milliseconds(40))
    }

    @Test func aBurstOfChangesReloadsOnce() async throws {
        let feed = ManualFeed()
        let session = try session(feed)
        let listening = Task { await session.start() }
        await Task.yield()
        feed.send(.remote)
        feed.send(.local)
        feed.send(.remote)
        try await Task.sleep(for: .milliseconds(200))
        #expect(session.generation == 1)
        feed.send(.local)
        try await Task.sleep(for: .milliseconds(200))
        #expect(session.generation == 2)
        listening.cancel()
        feed.finish()
    }

    @Test func reloadBumpsTheGeneration() throws {
        let session = try session(ManualFeed())
        session.reload()
        session.reload()
        #expect(session.generation == 2)
    }
}
