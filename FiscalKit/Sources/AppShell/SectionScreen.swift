import FeatureCore
import FeatureMine
import FeatureMoney
import FeatureSearch
import FeatureToday
import FeatureVotes
import SwiftUI

struct SectionScreen: View {
    let section: AppSection

    @ViewBuilder var body: some View {
        switch section {
        case .today: ModelHost(TodayModel()) { TodayScreen() }
        case .mine: ModelHost(MineModel()) { MineScreen() }
        case .votes: ModelHost(VotesModel()) { VotesScreen() }
        case .money: ModelHost(MoneyModel()) { MoneyScreen() }
        case .search: ModelHost(SearchModel()) { SearchScreen() }
        }
    }
}
