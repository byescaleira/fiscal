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
                    service: data, lens: services.todayLens(session.repositories.lens),
                    races: services.liveResultsService(),
                    follows: services.todayFollows(session.repositories.follows))
            ) {
                TodayScreen()
            }
        case .mine: ModelHost(MineModel(follows: session.repositories.follows)) { MineScreen() }
        case .votes: ModelHost(VotesModel(service: data)) { VotesScreen() }
        case .money: ModelHost(MoneyModel(service: data)) { MoneyScreen() }
        case .search: ModelHost(SearchModel(service: data)) { SearchScreen() }
        }
    }
}
