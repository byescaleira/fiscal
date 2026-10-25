import FeatureCore
import FiscalDomain
import Foundation
import Testing

@MainActor
struct DataExportModelTests {
    private let exportedAt = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func exportsADatedArchiveAsJSON() async throws {
        let exportedAt = exportedAt
        let export = DataExportModel(repositories: Repositories(), now: { exportedAt })
        await export.prepare()
        let archive = try #require(export.archive)
        #expect(export.isExporting)
        #expect(archive.fileName.hasSuffix("2027-01-15"))
        #expect(try DataArchive.decoded(from: archive.encoded()) == archive)
    }

    @Test func aFailedSaveReportsTheError() async {
        let export = DataExportModel(repositories: Repositories())
        await export.prepare()
        export.finish(.failure(CocoaError(.fileWriteNoPermission)))
        #expect(!export.isExporting)
        #expect(export.error == .onSave)
    }
}
