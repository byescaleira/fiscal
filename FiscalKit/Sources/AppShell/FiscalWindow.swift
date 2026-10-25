import FeatureCore
import FiscalDomain
import SwiftUI

@MainActor
public struct FiscalWindow {
    public let session: SessionModel
    public let navigation: FiscalNavigation

    public init(provider: any RepositoryProvider) {
        session = SessionModel(repositories: provider.repositories)
        navigation = FiscalNavigation()
    }
}

extension View {
    public func fiscalWindow(_ window: FiscalWindow) -> some View {
        environment(window.session)
            .environment(window.navigation)
    }
}
