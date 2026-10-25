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
        return LiveResultsModel(
            service: liveResultsService(), activities: RaceActivities(),
            environment: environment)
    }

    func liveResultsService() -> (any LiveResultsService)? {
        #if DEBUG
            if let showcase = ShowcaseLiveResults.fromLaunchArguments() { return showcase }
        #endif
        return LiveResultsClient.fromBundle()
    }

    func todayFollows(_ repository: any FollowRepository) -> any FollowRepository {
        #if DEBUG
            if let showcase = ShowcaseFollowRepository.fromLaunchArguments() { return showcase }
        #endif
        return repository
    }

    func publicData() -> (any PublicDataService)? {
        #if DEBUG
            if let showcase = ShowcasePublicData.fromLaunchArguments(
                roster: .bundled, indicators: .bundled)
            {
                return showcase
            }
        #endif
        return PublicDataClient.fromBundle()
    }

    public static var launchCloudSync: Bool {
        #if targetEnvironment(simulator)
            false
        #else
            true
        #endif
    }
}
