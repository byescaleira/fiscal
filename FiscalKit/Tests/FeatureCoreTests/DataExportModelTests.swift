import FeatureCore
import FiscalData
import FiscalDomain
import Foundation
import Testing

private struct FailingLens: LensRepository {
    func lens() async throws -> Lens? { throw FiscalError.onFetch }
    func save(_ lens: Lens) async throws {}
    func reset() async throws {}
}

@MainActor
struct DataExportModelTests {
    private let exportedAt = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func exportsTheLensAndTheFollowedPeopleAsJSON() async throws {
        let repositories = try FiscalDatabase.open(inMemory: true).repositories
        let exportedAt = exportedAt
        try await repositories.lens.save(Lens(themes: [.health, .taxes, .security]))
        try await repositories.follows.follow(
            PersonCard(
                slug: "kim-kataguiri", name: "Kim Kataguiri", office: .federalDeputy, uf: "sp",
                party: "UNIÃO", photo: nil, status: .inOffice), at: exportedAt)
        let export = DataExportModel(repositories: repositories, now: { exportedAt })
        await export.prepare()
        let archive = try #require(export.archive)
        #expect(export.isExporting)
        #expect(archive.lens?.themes == [.health, .taxes, .security])
        #expect(archive.following.map(\.card.slug) == ["kim-kataguiri"])
        #expect(archive.fileName.hasSuffix("2027-01-15"))
        #expect(try DataArchive.decoded(from: archive.encoded()) == archive)
    }

    @Test func aFailedReadReportsTheError() async throws {
        let follows = try FiscalDatabase.open(inMemory: true).repositories.follows
        let export = DataExportModel(
            repositories: Repositories(lens: FailingLens(), follows: follows))
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
