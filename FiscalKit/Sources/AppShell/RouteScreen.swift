import FeatureCore
import FeatureLiveResults
import SwiftUI

struct RouteScreen: View {
    let route: Route

    @ViewBuilder var body: some View {
        switch route {
        case .races: ModelHost(FiscalServices.shared.liveResults()) { LiveResultsScreen() }
        }
    }
}
