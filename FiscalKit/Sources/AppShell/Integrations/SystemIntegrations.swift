import FeatureCore
import SwiftUI

#if canImport(CoreSpotlight)
    import CoreSpotlight
#endif

struct SystemIntegrations: ViewModifier {
    @Environment(SessionModel.self) private var session
    @Environment(FiscalNavigation.self) private var navigation
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .task(id: session.generation) {
                IntegrationCenter.shared.syncWidgets()
                await IntegrationCenter.shared.refreshIndex(follows: session.repositories.follows)
                await HighlightAlertCenter.shared.activate()
            }
            .task(id: openRoutes) {
                await IntegrationCenter.shared.observe(
                    routes: openRoutes, follows: session.repositories.follows)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task { await HighlightAlertCenter.shared.activate() }
                }
                guard phase == .background else { return }
                IntegrationCenter.shared.syncWidgets()
                IntegrationCenter.shared.reloadWidgets()
            }
            #if canImport(CoreSpotlight)
                .onContinueUserActivity(CSSearchableItemActionType) { activity in
                    guard let url = SpotlightPeopleIndex.url(from: activity) else { return }
                    FiscalServices.shared.pendingURL = url
                }
            #endif
    }

    private var openRoutes: [Route] {
        navigation.paths.values.flatMap(\.self)
            + [navigation.inspector?.route].compactMap(\.self) + navigation.inspectorPath
    }
}
