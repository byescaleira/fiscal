import FeatureCore
import FiscalData
import FiscalDomain
import Foundation
import Testing

private struct FailingSupport: SupportRepository {
    func support() async throws -> SupportChoice? { throw FiscalError.onFetch }
    func save(_ support: SupportChoice) async throws {}
    func reset() async throws {}
}

@MainActor
struct DataExportModelTests {
    private let exportedAt = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func exportsTheSupportAndTheFollowedPeopleAsJSON() async throws {
        let repositories = try FiscalDatabase.open(inMemory: true).repositories
        let exportedAt = exportedAt
        try await repositories.support.save(SupportChoice(causes: [.health, .taxes, .security]))
        try await repositories.follows.follow(
            PersonCard(
                slug: "kim-kataguiri", name: "Kim Kataguiri", office: .federalDeputy, uf: "sp",
                party: "UNIÃO", photo: nil, status: .inOffice), at: exportedAt)
        let export = DataExportModel(repositories: repositories, now: { exportedAt })
        await export.prepare()
        let archive = try #require(export.archive)
        #expect(export.isExporting)
        #expect(archive.support?.causes == [.health, .taxes, .security])
        #expect(String(decoding: try archive.encoded(), as: UTF8.self).contains("lens") == false)
        #expect(archive.following.map(\.card.slug) == ["kim-kataguiri"])
        #expect(archive.fileName.hasSuffix("2027-01-15"))
        #expect(try DataArchive.decoded(from: archive.encoded()) == archive)
    }

    @Test func exportsTheLikedItems() async throws {
        let repositories = try FiscalDatabase.open(inMemory: true).repositories
        let liked = LikedItem(
            id: "vote-senado-7107", kind: .vote, title: "PEC 221/2019",
            day: CalendarDay(exportedAt), likedAt: exportedAt, voteID: "senado-7107")
        try await #require(repositories.likes).like(liked)
        let exportedAt = exportedAt
        let export = DataExportModel(repositories: repositories, now: { exportedAt })
        await export.prepare()
        let archive = try #require(export.archive)
        #expect(archive.liked == [liked])
        #expect(try DataArchive.decoded(from: archive.encoded()) == archive)
    }

    @Test func anArchiveFromBeforeLikesStillReads() throws {
        let json = #"{"exportedAt":"2026-11-01T12:00:00Z","following":[]}"#
        let archive = try DataArchive.decoded(from: Data(json.utf8))
        #expect(archive.liked == nil)
        #expect(archive.following.isEmpty)
        #expect(archive.support == nil)
    }

    @Test func aFailedReadReportsTheError() async throws {
        let follows = try FiscalDatabase.open(inMemory: true).repositories.follows
        let export = DataExportModel(
            repositories: Repositories(support: FailingSupport(), follows: follows))
        await export.prepare()
        #expect(export.archive == nil)
        #expect(!export.isExporting)
        #expect(export.error == .onFetch)
    }

    @Test func aFailedSaveReportsTheError() async throws {
        let export = DataExportModel(
            repositories: try FiscalDatabase.open(inMemory: true).repositories)
        await export.prepare()
        export.finish(.failure(CocoaError(.fileWriteNoPermission)))
        #expect(!export.isExporting)
        #expect(export.error == .onSave)
    }
}
