import Foundation
import Testing

@testable import FiscalDomain

struct FollowingSnapshotTests {
    @Test func putsPeopleWithNewsFirstAndKeepsSix() {
        let people = ["f", "e", "d", "c", "b", "a", "g"].map {
            FollowingFeedTests.card($0, $0.uppercased())
        }
        let updates = [
            FollowingUpdate(
                person: people[0], kind: .vote(FollowingFeedTests.vote("1", day: 20)),
                day: october(20)),
            FollowingUpdate(
                person: people[1], kind: .vote(FollowingFeedTests.vote("2", day: 30)),
                day: october(30)),
        ]
        let snapshot = FollowingSnapshot.make(followed: people, updates: updates, at: .distantPast)
        #expect(snapshot.entries.map(\.id) == ["e", "f", "a", "b", "c", "d"])
        #expect(snapshot.entries.first?.latest?.id == "e/vote/2")
    }

    @Test func writesAndReadsTheAppGroupFile() throws {
        let container = FileManager.default.temporaryDirectory
            .appending(path: "FollowingSnapshot-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: container) }
        #expect(FollowingSnapshot.read(in: container) == .empty)
        let snapshot = FollowingSnapshot.make(
            followed: [FollowingFeedTests.card("a", "Ana")], updates: [],
            at: Date(timeIntervalSince1970: 1_793_000_000))
        try snapshot.write(in: container)
        #expect(FollowingSnapshot.read(in: container) == snapshot)
    }
}
