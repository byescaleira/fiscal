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
    @Environment(SessionModel.self) private var session
    let route: Route

    @ViewBuilder var body: some View {
        let data = FiscalServices.shared.publicData()
        switch route {
        case .person(let slug):
            ModelHost(
                ProfileModel(slug: slug, service: data, follows: session.repositories.follows)
            ) {
                ProfileScreen()
            }
        case .vote(let id): ModelHost(VoteDetailModel(id: id, service: data)) { VoteDetailScreen() }
        case .compare(let slugs):
            ModelHost(CompareModel(slugs: slugs, service: data)) { CompareScreen() }
        case .races: ModelHost(FiscalServices.shared.liveResults()) { LiveResultsScreen() }
        case .lens: LensDestination()
        case .artists: ArtistsDestination()
        case .settings: SettingsScreen { SettingsExtraSection() }
        case .share(let subject):
            ModelHost(
                ShareModel(
                    subject: subject, service: data,
                    races: FiscalServices.shared.liveResultsService(),
                    lens: session.repositories.lens)
            ) {
                ShareScreen()
            }
        }
    }
}

private struct LensDestination: View {
    @Environment(LensContext.self) private var lens

    var body: some View {
        ModelHost(LensModel(context: lens)) { LensScreen() }
    }
}

private struct ArtistsDestination: View {
    @Environment(SessionModel.self) private var session

    var body: some View {
        ModelHost(ArtistsModel(lens: session.repositories.lens)) { ArtistsScreen() }
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
