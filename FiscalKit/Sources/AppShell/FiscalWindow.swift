import FeatureCore
import FeatureLiveResults
import FiscalData
import FiscalDomain
import SwiftUI

@MainActor
public struct FiscalWindow {
    public let session: SessionModel
    public let navigation: FiscalNavigation
    public let support: SupportContext
    public let portraits: PortraitStore
    public let liveResults: LiveResultsModel
    public let follow: FollowController
    public let followingBadge: FollowingBadge

    public init(provider: any RepositoryProvider) {
        let repositories = Self.repositories(provider.repositories)
        session = SessionModel(repositories: repositories, changes: provider.changes)
        navigation = FiscalNavigation()
        support = SupportContext(repository: repositories.support)
        portraits = PortraitStore()
        liveResults = FiscalServices.shared.liveResults()
        follow = FollowController(
            follows: repositories.follows,
            people: { try await FiscalServices.shared.publicData()?.people() ?? [] })
        followingBadge = FollowingBadge()
    }

    private static func repositories(_ repositories: Repositories) -> Repositories {
        #if DEBUG
            if let scenario = SupportScenario.fromLaunchArguments() {
                return Repositories(
                    support: ShowcaseSupportRepository(scenario: scenario),
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
            .environment(window.support)
            .environment(window.liveResults)
            .environment(window.follow)
            .environment(window.followingBadge)
            .fiscalPortraits(window.portraits)
            .environment(\.currentWindow, window)
    }
}

extension EnvironmentValues {
    @Entry var currentWindow: FiscalWindow?
}
