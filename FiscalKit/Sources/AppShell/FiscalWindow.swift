import FeatureCore
import FeatureLiveResults
import FiscalData
import FiscalDomain
import SwiftUI

@MainActor
public struct FiscalWindow {
    public let session: SessionModel
    public let navigation: FiscalNavigation
    public let lens: LensContext
    public let portraits: PortraitStore
    public let liveResults: LiveResultsModel

    public init(provider: any RepositoryProvider) {
        let repositories = Self.repositories(provider.repositories)
        session = SessionModel(repositories: repositories, changes: provider.changes)
        navigation = FiscalNavigation()
        lens = LensContext(repository: repositories.lens)
        portraits = PortraitStore()
        liveResults = FiscalServices.shared.liveResults()
    }

    private static func repositories(_ repositories: Repositories) -> Repositories {
        #if DEBUG
            if let scenario = LensScenario.fromLaunchArguments() {
                return Repositories(
                    lens: ShowcaseLensRepository(scenario: scenario),
                    follows: repositories.follows, investigations: repositories.investigations)
            }
        #endif
        return repositories
    }
}

extension View {
    public func fiscalWindow(_ window: FiscalWindow) -> some View {
        environment(window.session)
            .environment(window.navigation)
            .environment(window.lens)
            .environment(window.liveResults)
            .fiscalPortraits(window.portraits)
    }
}
