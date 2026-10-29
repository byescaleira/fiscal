import FiscalDomain
import Foundation
import SwiftData

public struct FiscalDatabase: RepositoryProvider {
    public static let cloudContainer = "iCloud.fiscal"
    public static let cloudStoreName = "Fiscal"
    public static let deviceStoreName = "Device"
    public let modelContainer: ModelContainer
    public let cloudIdentifier: String?
    let store: FiscalStore

    public init(modelContainer: ModelContainer, cloudIdentifier: String? = nil) {
        self.modelContainer = modelContainer
        self.cloudIdentifier = cloudIdentifier
        store = FiscalStore(modelContainer: modelContainer)
    }

    public static func open(inMemory: Bool = false, cloudSync: Bool = true, directory: URL? = nil)
        throws -> FiscalDatabase
    {
        let cloud: ModelConfiguration.CloudKitDatabase =
            inMemory || !cloudSync ? .none : .private(cloudContainer)
        let configurations = [
            configuration(
                cloudStoreName, models: FiscalSchemaV3.cloudModels, inMemory: inMemory,
                directory: directory, cloud: cloud),
            configuration(
                deviceStoreName, models: FiscalSchemaV3.deviceModels, inMemory: inMemory,
                directory: directory, cloud: .none),
        ]
        let container = try opening.withLock {
            try ModelContainer(
                for: Schema(versionedSchema: FiscalSchemaV3.self),
                migrationPlan: FiscalMigrationPlan.self, configurations: configurations)
        }
        try excludeDeviceStoreFromBackup(container)
        let syncs = !inMemory && cloudSync
        return FiscalDatabase(
            modelContainer: container, cloudIdentifier: syncs ? cloudContainer : nil)
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

    public var changes: any StorageChangeFeed { store.changeHub }

    public var repositories: Repositories {
        Repositories(
            lens: SwiftDataLensRepository(store: store),
            follows: SwiftDataFollowRepository(store: store),
            investigations: SwiftDataInvestigationRepository(
                store: store, cloudIdentifier: cloudIdentifier))
    }
}
