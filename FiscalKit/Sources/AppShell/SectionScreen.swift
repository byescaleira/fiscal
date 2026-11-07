import FeatureCore
import FeatureFeed
import FeatureLiveResults
import FeatureMoney
import FeatureRegion
import FeatureSearch
import FeatureVotes
import FiscalDomain
import SwiftUI

struct SectionScreen: View {
    @Environment(SessionModel.self) private var session
    let section: AppSection

    @ViewBuilder var body: some View {
        let data = FiscalServices.shared.publicData()
        switch section {
        case .feed:
            let services = FiscalServices.shared
            ModelHost(
                FeedModel(
                    service: data, races: services.liveResultsService(),
                    follows: services.feedFollows(session.repositories.follows))
            ) {
                FeedScreen { race in RaceHeroCard(race: race, opensDetail: true) }
            }
        case .region:
            ModelHost(RegionModel(service: data)) {
                RegionScreen()
            }
        case .votes:
            ModelHost(VotesModel(service: data)) { VotesScreen() }
        case .money:
            ModelHost(MoneyModel(service: data)) { MoneyScreen() }
        case .search:
            ModelHost(
                SearchModel(
                    service: data,
                    board: InvestigationModel(
                        service: data, follows: session.repositories.follows,
                        repository: session.repositories.investigations,
                        homeUF: HomePlace.chosenUF(in: .standard),
                        usesModel: FiscalServices.shared.usesIntelligence))
            ) {
                SearchScreen()
            }
        }
    }
}
