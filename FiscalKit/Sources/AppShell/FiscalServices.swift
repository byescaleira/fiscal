import FeatureLiveResults
import FiscalData
import FiscalDomain
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

    func liveResults() -> LiveResultsModel {
        #if DEBUG
            let environment = PushEnvironment.development
        #else
            let environment = PushEnvironment.production
        #endif
        var service: (any LiveResultsService)? = LiveResultsClient.fromBundle()
        #if DEBUG
            if let showcase = ShowcaseLiveResults.fromLaunchArguments() { service = showcase }
        #endif
        return LiveResultsModel(
            service: service, activities: RaceActivities(), environment: environment)
    }

    public static var launchCloudSync: Bool {
        #if targetEnvironment(simulator)
            false
        #else
            true
        #endif
    }
}
