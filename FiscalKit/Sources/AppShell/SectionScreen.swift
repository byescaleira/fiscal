import FeatureCore
import FeatureLiveResults
import FeatureMine
import FeatureMoney
import FeatureSearch
import FeatureToday
import FeatureVotes
import FiscalDomain
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
                TodayScreen { race in RaceHeroCard(race: race, opensDetail: true) }
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
        case .search:
            ModelHost(
                SearchModel(
                    service: data,
                    board: InvestigationModel(
                        service: data, lens: session.repositories.lens,
                        follows: session.repositories.follows,
                        repository: session.repositories.investigations,
                        homeUF: HomePlace.chosenUF(in: .standard),
                        usesModel: FiscalServices.shared.usesIntelligence))
            ) {
                SearchScreen()
            }
        }
    }
}
