import FiscalDomain
import Foundation
import SwiftData
import Testing

@testable import FiscalData

struct SchemaMigrationTests {
    @Test func theMigrationPlanOpensAnInMemoryStore() throws {
        let container = try ModelContainer(
            for: Schema(versionedSchema: FiscalSchemaV3.self),
            migrationPlan: FiscalMigrationPlan.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        #expect(container.schema.entities.count == FiscalSchemaV3.models.count)
    }

    @Test func everyShippedVersionKeepsItsOwnClasses() {
        let versions: [[any PersistentModel.Type]] = [
            FiscalSchemaV1.models, FiscalSchemaV2.models, FiscalSchemaV3.models,
        ]
        let identities = versions.flatMap { $0.map(ObjectIdentifier.init) }
        #expect(Set(identities).count == identities.count)
        #expect(FiscalMigrationPlan.schemas.count == FiscalMigrationPlan.stages.count + 1)
    }

    @Test func aSecondVersionStoreOpensWithTheCurrentSchema() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(
                path: "SchemaMigrationTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try writeSecondVersion(in: directory)
        let repositories = try FiscalDatabase.open(cloudSync: false, directory: directory)
            .repositories
        #expect(try await repositories.lens.lens()?.supported == ["lula"])
        #expect(try await repositories.follows.isFollowing(slug: "tabata-amaral"))
        #expect(try await repositories.investigations?.investigations().isEmpty == true)
    }

    private func writeSecondVersion(in directory: URL) throws {
        let configurations = [
            ModelConfiguration(
                FiscalDatabase.cloudStoreName, schema: Schema(FiscalSchemaV2.cloudModels),
                url: directory.appending(path: "\(FiscalDatabase.cloudStoreName).store"),
                cloudKitDatabase: .none),
            ModelConfiguration(
                FiscalDatabase.deviceStoreName, schema: Schema(FiscalSchemaV2.deviceModels),
                url: directory.appending(path: "\(FiscalDatabase.deviceStoreName).store"),
                cloudKitDatabase: .none),
        ]
        let container = try ModelContainer(
            for: Schema(versionedSchema: FiscalSchemaV2.self), configurations: configurations)
        let context = ModelContext(container)
        let follow = FiscalSchemaV2.FollowEntity(slug: "tabata-amaral", followedAt: .now)
        follow.name = "Tabata Amaral"
        follow.office = Office.federalDeputy.rawValue
        follow.uf = "sp"
        follow.party = "PSB"
        follow.status = PersonStatus.inOffice.rawValue
        context.insert(follow)
        let lens = FiscalSchemaV2.LensEntity(updatedAt: .now)
        lens.themeKeys = "health,taxes"
        lens.supportedKeys = "lula"
        context.insert(lens)
        try context.save()
    }
}
