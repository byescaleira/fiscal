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

public enum FiscalMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [FiscalSchemaV1.self]
    }
    public static var stages: [MigrationStage] {
        []
    }
}
