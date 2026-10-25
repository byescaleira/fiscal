import FeatureCore
import FeatureLens
import FeatureLiveResults
import FeatureProfile
import FeatureSearch
import FeatureSettings
import FeatureShare
import FeatureVotes
import FiscalDesignSystem
import SwiftUI

struct RouteScreen: View {
    let route: Route

    @ViewBuilder var body: some View {
        switch route {
        case .person(let slug): ModelHost(ProfileModel(slug: slug)) { ProfileScreen() }
        case .vote(let id): ModelHost(VoteDetailModel(id: id)) { VoteDetailScreen() }
        case .compare(let slugs): ModelHost(CompareModel(slugs: slugs)) { CompareScreen() }
        case .races: ModelHost(FiscalServices.shared.liveResults()) { LiveResultsScreen() }
        case .lens: LensDestination()
        case .artists: ArtistsDestination()
        case .settings: SettingsScreen { SettingsExtraSection() }
        }
    }
}

private struct LensDestination: View {
    var body: some View {
        ModelHost(LensModel()) { LensScreen() }
    }
}

private struct ArtistsDestination: View {
    var body: some View {
        ModelHost(ArtistsModel()) { ArtistsScreen() }
    }
}

private struct SettingsExtraSection: View {
    var body: some View {
        Section {
            SettingsRow("Lens", symbol: "eyeglasses", color: .retroTeal) {
                LensDestination()
            }
            SettingsRow("Artists", symbol: "paintpalette", color: .retroPlum) {
                ArtistsDestination()
            }
        } header: {
            Text("Your Fiscal")
        }
    }
}
