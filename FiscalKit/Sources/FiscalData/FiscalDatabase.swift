import FiscalDomain
import Foundation
import SwiftData

public struct FiscalDatabase: RepositoryProvider {
    public static let cloudContainer = "iCloud.fiscal"
    public let modelContainer: ModelContainer
    let store: FiscalStore

    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        store = FiscalStore(modelContainer: modelContainer)
    }

    public static func open(inMemory: Bool = false, cloudSync: Bool = true, storeURL: URL? = nil)
        throws -> FiscalDatabase
    {
        let schema = Schema(versionedSchema: FiscalSchemaV1.self)
        let database: ModelConfiguration.CloudKitDatabase =
            inMemory || !cloudSync ? .none : .private(cloudContainer)
        let configuration =
            if let storeURL {
                ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: database)
            } else {
                ModelConfiguration(
                    schema: schema, isStoredInMemoryOnly: inMemory, cloudKitDatabase: database)
            }
        return FiscalDatabase(
            modelContainer: try ModelContainer(
                for: schema, migrationPlan: FiscalMigrationPlan.self,
                configurations: configuration))
    }

    public var storeURL: URL? { modelContainer.configurations.first?.url }

    public var repositories: Repositories {
        Repositories(items: SwiftDataItemRepository(store: store))
    }
}
