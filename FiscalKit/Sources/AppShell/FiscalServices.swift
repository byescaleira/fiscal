import FiscalData
import Foundation
import Observation

@MainActor @Observable
public final class FiscalServices {
    public static let shared = FiscalServices()
    public var pendingURL: URL?
    @ObservationIgnored private var opening: Task<FiscalDatabase, any Error>?

    private init() {}

    public func database(cloudSync: Bool) async throws -> FiscalDatabase {
        if let opening {
            do { return try await opening.value } catch { self.opening = nil }
        }
        let task = Task.detached(priority: .userInitiated) {
            try FiscalDatabase.open(cloudSync: cloudSync)
        }
        opening = task
        do {
            return try await task.value
        } catch {
            opening = nil
            throw error
        }
    }

    public static var launchCloudSync: Bool {
        #if targetEnvironment(simulator)
            false
        #else
            true
        #endif
    }
}
