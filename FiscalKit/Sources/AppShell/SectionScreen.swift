import FeatureCore
import FeatureLiveResults
import FeatureSettings
import SwiftUI

struct SectionScreen: View {
    let section: AppSection

    @ViewBuilder var body: some View {
        switch section {
        case .today: ModelHost(FiscalServices.shared.liveResults()) { LiveResultsScreen() }
        case .settings: SettingsScreen()
        }
    }
}
