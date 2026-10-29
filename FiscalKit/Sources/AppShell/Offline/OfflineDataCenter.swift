import FeatureSettings
import FiscalData
import FiscalDomain
import Foundation

#if os(iOS) || os(visionOS)
    import BackgroundTasks
#endif

@MainActor
public final class OfflineDataCenter {
    public static let shared = OfflineDataCenter()
    public static let refreshIdentifier = "com.byescaleira.fiscal.offline-refresh"

    private static let openInterval: TimeInterval = 600
    private static let backgroundInterval: TimeInterval = 4 * 60 * 60

    public let model: OfflineDataModel?
    private let coordinator: OfflinePackCoordinator?

    private init() {
        guard FiscalServices.shared.publicData() is PublicDataClient,
            let updater = OfflinePackUpdater.fromBundle()
        else {
            coordinator = nil
            model = nil
            return
        }
        let coordinator = OfflinePackCoordinator(updater: updater) {
            await OfflineDataCenter.request()
        }
        self.coordinator = coordinator
        model = OfflineDataModel(service: coordinator)
    }

    public func refreshIfDue() async {
        await coordinator?.refreshIfDue(every: Self.openInterval)
        await model?.load()
    }

    public func refreshInBackground(store: AppReleaseStore = .shared) async {
        guard Self.refreshesInBackground(store: store) else { return }
        scheduleBackgroundRefresh()
        _ = try? await coordinator?.refresh()
    }

    static func refreshesInBackground(store: AppReleaseStore) -> Bool {
        !store.blocks
    }

    func cancelBackgroundRefresh() {
        #if os(iOS) || os(visionOS)
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.refreshIdentifier)
        #endif
    }

    public func scheduleBackgroundRefresh() {
        #if os(iOS) || os(visionOS)
            guard coordinator != nil else { return }
            let request = BGAppRefreshTaskRequest(identifier: Self.refreshIdentifier)
            request.earliestBeginDate = Date(timeIntervalSinceNow: Self.backgroundInterval)
            try? BGTaskScheduler.shared.submit(request)
        #endif
    }

    nonisolated static func request() async -> OfflinePackRequest {
        let place = UserDefaults.standard.string(forKey: HomePlace.mineKey)
        guard
            let database = try? await FiscalServices.shared.database(
                cloudSync: FiscalServices.launchCloudSync)
        else { return OfflinePackRequest(placeCode: place) }
        let repositories = database.repositories
        let followed = (try? await repositories.follows.followed()) ?? []
        let supported = (try? await repositories.lens.lens())?.supported ?? []
        return OfflinePackRequest(
            followed: followed.map(\.card.slug), supported: supported, placeCode: place)
    }
}
