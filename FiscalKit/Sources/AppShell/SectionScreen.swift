import FeatureCore
import FeatureHome
import FeatureSettings
import SwiftUI

struct SectionScreen: View {
    @Environment(SessionModel.self) private var session
    let section: AppSection

    @ViewBuilder var body: some View {
        switch section {
        case .home: ModelHost(HomeModel(repositories: session.repositories)) { HomeScreen() }
        case .settings: SettingsScreen()
        }
    }
}
