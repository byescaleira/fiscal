import FeatureCore
import FeatureLiveResults
import FeatureSettings
import SwiftUI

struct SectionScreen: View {
    @Environment(SessionModel.self) private var session
    let section: AppSection

    @ViewBuilder var body: some View {
        switch section {
        case .home: ModelHost(FiscalServices.shared.liveResults()) { LiveResultsScreen() }
        case .settings: SettingsScreen()
        }
    }
}
