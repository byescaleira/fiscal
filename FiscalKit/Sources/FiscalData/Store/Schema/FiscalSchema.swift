import Foundation
import SwiftData

public enum FiscalSchemaV3: VersionedSchema {
    public static var versionIdentifier: Schema.Version { .init(3, 0, 0) }
    public static var models: [any PersistentModel.Type] {
        cloudModels + deviceModels
    }
    public static var cloudModels: [any PersistentModel.Type] {
        [FollowEntity.self, InvestigationEntity.self]
    }
    public static var deviceModels: [any PersistentModel.Type] {
        [LensEntity.self]
    }
}

public enum FiscalMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [FiscalSchemaV1.self, FiscalSchemaV2.self, FiscalSchemaV3.self]
    }
    public static var stages: [MigrationStage] {
        [dropStance, addInvestigations]
    }

    static let dropStance = MigrationStage.lightweight(
        fromVersion: FiscalSchemaV1.self, toVersion: FiscalSchemaV2.self)

    static let addInvestigations = MigrationStage.lightweight(
        fromVersion: FiscalSchemaV2.self, toVersion: FiscalSchemaV3.self)
}
