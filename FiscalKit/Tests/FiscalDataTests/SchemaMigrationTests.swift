import FiscalDomain
import Foundation
import SwiftData
import Testing

@testable import FiscalData

struct SchemaMigrationTests {
    @Test func theMigrationPlanOpensAnInMemoryStore() throws {
        let container = try ModelContainer(
            for: Schema(versionedSchema: FiscalSchemaV4.self),
            migrationPlan: FiscalMigrationPlan.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        #expect(container.schema.entities.count == FiscalSchemaV4.models.count)
    }

    @Test func everyShippedVersionKeepsItsOwnClasses() {
        let versions: [[any PersistentModel.Type]] = [
            FiscalSchemaV1.models, FiscalSchemaV2.models, FiscalSchemaV3.models,
            FiscalSchemaV4.models,
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
        let support = try #require(try await repositories.support.support())
        #expect(support.people == ["lula"])
        #expect(support.causes == [.health, .taxes])
        #expect(try await repositories.lens.lens() == nil)
        #expect(try await repositories.support.support() == support)
        #expect(try await repositories.follows.isFollowing(slug: "tabata-amaral"))
        #expect(try await repositories.investigations?.investigations().isEmpty == true)
    }

    @Test func savingReplacesTheOldLens() async throws {
        let repositories = try FiscalDatabase.open(inMemory: true).repositories
        try await repositories.lens.save(Lens(themes: [.health], supported: ["pessoa-a"]))
        try await repositories.support.save(SupportChoice(causes: [.taxes]))
        #expect(try await repositories.lens.lens() == nil)
        #expect(try await repositories.support.support() == SupportChoice(causes: [.taxes]))
    }

    @Test func erasingRemovesTheOldLensToo() async throws {
        let repositories = try FiscalDatabase.open(inMemory: true).repositories
        try await repositories.lens.save(Lens(themes: [.health], supported: ["pessoa-a"]))
        try await repositories.support.reset()
        #expect(try await repositories.support.support() == nil)
        #expect(try await repositories.lens.lens() == nil)
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
        lens.themeKeys = [Theme.health, .taxes].map(\.rawValue).joined(separator: ",")
        lens.supportedKeys = "lula"
        context.insert(lens)
        try context.save()
    }
}
