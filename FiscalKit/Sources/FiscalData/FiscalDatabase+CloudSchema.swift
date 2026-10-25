#if DEBUG
    import CoreData
    import Foundation
    import OSLog
    import SwiftData

    extension FiscalDatabase {
        private static let schemaLogger = Logger(
            subsystem: "com.byescaleira.fiscal", category: "CloudSchema")

        public static func initializeCloudSchema() {
            let url = FileManager.default.temporaryDirectory
                .appending(path: "CloudSchema-\(UUID().uuidString).store")
            guard
                let model = NSManagedObjectModel.makeManagedObjectModel(
                    for: FiscalSchemaV1.models)
            else {
                schemaLogger.error("Cloud schema: model could not be built")
                return
            }
            let description = NSPersistentStoreDescription(url: url)
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: cloudContainer)
            description.shouldAddStoreAsynchronously = false
            let container = NSPersistentCloudKitContainer(
                name: "CloudSchema", managedObjectModel: model)
            container.persistentStoreDescriptions = [description]
            var loadError: (any Error)?
            container.loadPersistentStores { _, error in loadError = error }
            if let loadError {
                schemaLogger.error("Cloud schema: \(loadError.localizedDescription)")
                return
            }
            do {
                try container.initializeCloudKitSchema()
                schemaLogger.notice("Cloud schema: initialized")
            } catch {
                schemaLogger.error("Cloud schema: \(error.localizedDescription)")
            }
            for store in container.persistentStoreCoordinator.persistentStores {
                try? container.persistentStoreCoordinator.remove(store)
            }
            try? FileManager.default.removeItem(at: url)
        }
    }
#endif
