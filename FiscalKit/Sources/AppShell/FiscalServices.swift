import FeatureCore
import FeatureLiveResults
import FiscalData
import FiscalDomain
import Foundation
import Observation

@MainActor @Observable
public final class FiscalServices {
    public static let shared = FiscalServices()
    public var pendingURL: URL?
    public var flags: FeatureFlags?
    let raceRegistration = HoldGate()
    @ObservationIgnored private var opening: Task<FiscalDatabase, any Error>?
    @ObservationIgnored private var resolvedPublicData: PublicDataSlot?

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

    func isOn(_ flag: FeatureFlag) -> Bool {
        flags?.isOn(flag) ?? flag.defaultValue
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
        guard isOn(.liveResults) else { return nil }
        #if DEBUG
            if let showcase = ShowcaseLiveResults.fromLaunchArguments() { return showcase }
        #endif
        return LiveResultsClient.fromBundle().map {
            HeldLiveResultsService(base: $0, gate: raceRegistration)
        }
    }

    func highlightAlertService() -> (any HighlightAlertService)? {
        #if DEBUG
            if ShowcaseLiveResults.fromLaunchArguments() != nil { return nil }
        #endif
        return LiveResultsClient.fromBundle()
    }

    var explainer: Explainer {
        isOn(.intelligence) ? .shared : .fixed
    }

    var usesIntelligence: Bool {
        isOn(.intelligence)
    }

    func todayFollows(_ repository: any FollowRepository) -> any FollowRepository {
        #if DEBUG
            if let showcase = ShowcaseFollowRepository.fromLaunchArguments() { return showcase }
        #endif
        return repository
    }

    func publicData() -> (any PublicDataService)? {
        if let resolvedPublicData { return resolvedPublicData.service }
        let slot = PublicDataSlot(service: Self.makePublicData())
        resolvedPublicData = slot
        return slot.service
    }

    private static func makePublicData() -> (any PublicDataService)? {
        #if DEBUG
            if let showcase = ShowcasePublicData.fromLaunchArguments(
                roster: .bundled, indicators: .bundled)
            {
                return showcase
            }
        #endif
        return PublicDataClient.fromBundle()
    }

    func workspace(store: AppReleaseStore = .shared) throws -> IntegrationActions {
        if store.blocks { throw UpdateRequiredError() }
        guard let service = publicData() else { throw IntegrationError.unavailable }
        return IntegrationActions(service: service)
    }

    nonisolated public static let launchCloudSync: Bool = {
        #if targetEnvironment(simulator)
            false
        #else
            CloudSyncPreference.isOn()
        #endif
    }()
}

private struct PublicDataSlot {
    let service: (any PublicDataService)?
}
