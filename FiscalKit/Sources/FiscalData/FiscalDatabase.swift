import FiscalDomain
import Foundation
import SwiftData

public struct FiscalDatabase: RepositoryProvider {
    public static let cloudContainer = "iCloud.fiscal"
    public static let cloudStoreName = "Fiscal"
    public static let deviceStoreName = "Device"
    public let modelContainer: ModelContainer
    let store: FiscalStore

    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        store = FiscalStore(modelContainer: modelContainer)
    }

    public static func open(inMemory: Bool = false, cloudSync: Bool = true, directory: URL? = nil)
        throws -> FiscalDatabase
    {
        let cloud: ModelConfiguration.CloudKitDatabase =
            inMemory || !cloudSync ? .none : .private(cloudContainer)
        let configurations = [
            configuration(
                cloudStoreName, models: FiscalSchemaV2.cloudModels, inMemory: inMemory,
                directory: directory, cloud: cloud),
            configuration(
                deviceStoreName, models: FiscalSchemaV2.deviceModels, inMemory: inMemory,
                directory: directory, cloud: .none),
        ]
        let container = try opening.withLock {
            try ModelContainer(
                for: Schema(versionedSchema: FiscalSchemaV2.self),
                migrationPlan: FiscalMigrationPlan.self, configurations: configurations)
        }
        try excludeDeviceStoreFromBackup(container)
        return FiscalDatabase(modelContainer: container)
    }

    private static let opening = NSLock()

    private static func configuration(
        _ name: String, models: [any PersistentModel.Type], inMemory: Bool, directory: URL?,
        cloud: ModelConfiguration.CloudKitDatabase
    ) -> ModelConfiguration {
        let schema = Schema(models)
        if let directory {
            return ModelConfiguration(
                name, schema: schema, url: directory.appending(path: "\(name).store"),
                cloudKitDatabase: cloud)
        }
        return ModelConfiguration(
            name, schema: schema, isStoredInMemoryOnly: inMemory, cloudKitDatabase: cloud)
    }

    public var repositories: Repositories {
        Repositories(
            lens: SwiftDataLensRepository(store: store),
            follows: SwiftDataFollowRepository(store: store))
    }
}
