import Foundation
import SwiftData

extension FiscalDatabase {
    public var deviceStoreURL: URL? {
        modelContainer.configurations.first { $0.name == Self.deviceStoreName }?.url
    }

    static func excludeDeviceStoreFromBackup(_ container: ModelContainer) throws {
        let device = container.configurations.filter {
            $0.name == deviceStoreName && !$0.isStoredInMemoryOnly
        }
        for configuration in device {
            try excludeFromBackup(store: configuration.url)
        }
    }

    static func excludeFromBackup(store: URL) throws {
        let directory = store.deletingLastPathComponent()
        for suffix in ["", "-wal", "-shm"] {
            var file = directory.appending(path: store.lastPathComponent + suffix)
            guard FileManager.default.fileExists(atPath: file.path(percentEncoded: false)) else {
                continue
            }
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try file.setResourceValues(values)
        }
    }
}
