import FiscalDomain
import Foundation
import Testing

@testable import FiscalData

struct LikeStoreTests {
    private func item(_ id: String, at seconds: TimeInterval) throws -> LikedItem {
        LikedItem(
            id: "event-\(id)", kind: .event, title: "Evento \(id)",
            day: try #require(CalendarDay(year: 2026, month: 11, day: 6)),
            likedAt: Date(timeIntervalSince1970: seconds))
    }

    private func open() throws -> (FiscalDatabase, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "LikeStoreTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (try FiscalDatabase.open(cloudSync: false, directory: directory), directory)
    }

    @Test func likingTwiceKeepsOneRow() async throws {
        let (database, directory) = try open()
        defer { try? FileManager.default.removeItem(at: directory) }
        let likes = try #require(database.repositories.likes)
        try await likes.like(try item("a", at: 1))
        try await likes.like(try item("a", at: 2))
        let liked = try await likes.liked()
        #expect(liked.map(\.id) == ["event-a"])
        #expect(liked.first?.likedAt == Date(timeIntervalSince1970: 2))
    }

    @Test func theNewestComesFirst() async throws {
        let (database, directory) = try open()
        defer { try? FileManager.default.removeItem(at: directory) }
        let likes = try #require(database.repositories.likes)
        try await likes.like(try item("a", at: 1))
        try await likes.like(try item("b", at: 3))
        try await likes.like(try item("c", at: 2))
        #expect(try await likes.liked().map(\.id) == ["event-b", "event-c", "event-a"])
    }

    @Test func unlikingRemovesOnlyThatItem() async throws {
        let (database, directory) = try open()
        defer { try? FileManager.default.removeItem(at: directory) }
        let likes = try #require(database.repositories.likes)
        try await likes.like(try item("a", at: 1))
        try await likes.like(try item("b", at: 2))
        try await likes.unlike(id: "event-a")
        #expect(try await likes.liked().map(\.id) == ["event-b"])
    }

    @Test func resettingRemovesEverything() async throws {
        let (database, directory) = try open()
        defer { try? FileManager.default.removeItem(at: directory) }
        let likes = try #require(database.repositories.likes)
        try await likes.like(try item("a", at: 1))
        try await likes.like(try item("b", at: 2))
        try await likes.reset()
        #expect(try await likes.liked().isEmpty)
    }

    @Test func aLikeSurvivesReopeningAndStaysOutOfBackups() async throws {
        let (database, directory) = try open()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = try #require(URL(string: "https://projetocomprova.com.br/1"))
        let day = try #require(CalendarDay(year: 2026, month: 10, day: 14))
        let check = LikedItem(
            id: "check-1", kind: .check, title: "Checagem", day: day,
            likedAt: Date(timeIntervalSince1970: 5), url: url)
        try await #require(database.repositories.likes).like(check)
        let reopened = try FiscalDatabase.open(cloudSync: false, directory: directory)
        #expect(try await reopened.repositories.likes?.liked() == [check])
        let store = try #require(reopened.deviceStoreURL)
        let values = try store.resourceValues(forKeys: [.isExcludedFromBackupKey])
        #expect(values.isExcludedFromBackup == true)
    }

    @Test func likingDoesNotTellTheSessionToReload() async throws {
        let (database, directory) = try open()
        defer { try? FileManager.default.removeItem(at: directory) }
        let likes = try #require(database.repositories.likes)
        let before = database.store.changeHub.localRevision
        try await likes.like(try item("a", at: 1))
        try await likes.unlike(id: "event-a")
        try await likes.like(try item("b", at: 2))
        try await likes.reset()
        #expect(database.store.changeHub.localRevision == before)
    }
}
