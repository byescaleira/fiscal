import FeatureCore
import FiscalData
import FiscalDomain
import Foundation
import Testing

private struct FailingItems: ItemRepository {
    func items() async throws -> [Item] { throw FiscalError.onFetch }
    func item(id: String) async throws -> Item? { nil }
    func save(_ item: Item) async throws {}
    func delete(id: String) async throws {}
}

@MainActor
struct DataExportModelTests {
    private let exportedAt = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func exportsEveryItemAsJSON() async throws {
        let repositories = try FiscalDatabase.open(inMemory: true).repositories
        let exportedAt = exportedAt
        try await repositories.items.save(
            Item(id: "walk", title: "Morning walk", createdAt: exportedAt))
        try await repositories.items.save(Item(id: "read", title: "Read", createdAt: exportedAt))
        let export = DataExportModel(repositories: repositories, now: { exportedAt })
        await export.prepare()
        let archive = try #require(export.archive)
        #expect(export.isExporting)
        #expect(Set(archive.items.map(\.id)) == ["walk", "read"])
        #expect(archive.fileName.hasSuffix("2027-01-15"))
        #expect(try DataArchive.decoded(from: archive.encoded()) == archive)
    }

    @Test func aFailedReadReportsTheError() async {
        let export = DataExportModel(repositories: Repositories(items: FailingItems()))
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
