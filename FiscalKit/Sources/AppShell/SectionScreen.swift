import FeatureCore
import FeatureMine
import FeatureMoney
import FeatureSearch
import FeatureToday
import FeatureVotes
import SwiftUI

struct SectionScreen: View {
    @Environment(SessionModel.self) private var session
    let section: AppSection

    @ViewBuilder var body: some View {
        let data = FiscalServices.shared.publicData()
        switch section {
        case .today:
            let services = FiscalServices.shared
            ModelHost(
                TodayModel(
                    service: data, lens: session.repositories.lens,
                    races: services.liveResultsService(),
                    follows: services.todayFollows(session.repositories.follows))
            ) {
                ModelHost(services.liveResults()) { TodayScreen() }
            }
        case .mine:
            ModelHost(MineModel(service: data, follows: session.repositories.follows)) {
                MineScreen()
            }
        case .votes:
            ModelHost(VotesModel(service: data, lens: session.repositories.lens)) {
                VotesScreen()
            }
        case .money:
            ModelHost(MoneyModel(service: data, lens: session.repositories.lens)) { MoneyScreen() }
        case .search: ModelHost(SearchModel(service: data)) { SearchScreen() }
        }
    }
}
