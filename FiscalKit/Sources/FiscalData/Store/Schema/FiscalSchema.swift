import Foundation
import SwiftData

public enum FiscalSchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { .init(1, 0, 0) }
    public static var models: [any PersistentModel.Type] {
        cloudModels + deviceModels
    }
    public static var cloudModels: [any PersistentModel.Type] {
        [FollowEntity.self]
    }
    public static var deviceModels: [any PersistentModel.Type] {
        [LensEntity.self]
    }
}

public enum FiscalSchemaV2: VersionedSchema {
    public static var versionIdentifier: Schema.Version { .init(2, 0, 0) }
    public static var models: [any PersistentModel.Type] {
        cloudModels + deviceModels
    }
    public static var cloudModels: [any PersistentModel.Type] {
        [FollowEntity.self]
    }
    public static var deviceModels: [any PersistentModel.Type] {
        [LensEntity.self]
    }
}

public typealias LensEntity = FiscalSchemaV2.LensEntity

public enum FiscalMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [FiscalSchemaV1.self, FiscalSchemaV2.self]
    }
    public static var stages: [MigrationStage] {
        [dropStance]
    }

    static let dropStance = MigrationStage.lightweight(
        fromVersion: FiscalSchemaV1.self, toVersion: FiscalSchemaV2.self)
}
