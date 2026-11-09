import FeatureContent
import FeatureCore
import FeatureFeed
import FeatureLiveResults
import FeatureMemory
import FeatureMoney
import FeatureProfile
import FeatureRegion
import FeatureSearch
import FeatureSettings
import FeatureShare
import FeatureSupport
import FeatureVotes
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct RouteScreen: View {
    @Environment(SessionModel.self) private var session
    let route: Route

    @ViewBuilder var body: some View {
        let data = FiscalServices.shared.publicData()
        switch route {
        case .person(let slug):
            ModelHost(
                ProfileModel(
                    slug: slug, service: data, follows: session.repositories.follows)
            ) {
                ProfileScreen()
            }
        case .vote(let id):
            ModelHost(
                VoteDetailModel(
                    id: id, service: data, support: session.repositories.support,
                    homeUF: HomePlace.chosenUF(in: .standard))
            ) {
                VoteDetailScreen()
            }
        case .voteBallots(let id, let party):
            ModelHost(VoteDetailModel(id: id, service: data, party: party)) {
                VoteBallotsScreen()
            }
        case .agenda:
            ModelHost(VotesModel(service: data)) { VotesAgendaScreen() }
        case .following:
            ModelHost(
                FollowingModel(
                    service: data,
                    follows: FiscalServices.shared.feedFollows(session.repositories.follows))
            ) {
                FollowingScreen()
            }
        case .expenses(let slug, let year):
            ModelHost(ExpensesModel(slug: slug, year: year, service: data)) { ExpensesScreen() }
        case .compare(let slugs):
            ModelHost(CompareModel(slugs: slugs, service: data)) { CompareScreen() }
        case .races: LiveResultsScreen()
        case .race(let id): RaceDetailScreen(raceID: id)
        case .roster(let title, let people):
            RegionRosterScreen(roster: RegionRoster(title: title, people: people))
        case .spenders(let title, let spenders, let year):
            ModelHost(MoneyModel(service: data)) {
                MoneySpendersDestination(title: title, spenders: spenders, year: year)
            }
        case .awaiting:
            ModelHost(
                MemoryModel(service: data, races: FiscalServices.shared.liveResultsService())
            ) {
                AwaitingDestination()
            }
        case .memory:
            ModelHost(
                MemoryModel(service: data, races: FiscalServices.shared.liveResultsService())
            ) {
                MemoryScreen()
            }
        case .pastElection(let year):
            ModelHost(ElectionYearModel(year: year, service: data)) { ElectionYearScreen() }
        case .pastRace(let id):
            ModelHost(PastRaceModel(id: id, service: data)) { PastRaceScreen() }
        case .period(let id): ModelHost(PeriodModel(id: id, service: data)) { PeriodScreen() }
        case .studyGuide(let id):
            ModelHost(StudyGuideModel(id: id, service: data)) { StudyGuideScreen() }
        case .artists: ArtistsDestination()
        case .settings:
            SettingsScreen(service: data) {
                SupportDestination()
            } artists: {
                ArtistsDestination()
            }
        case .share(let subject):
            ModelHost(
                ShareModel(
                    subject: subject, service: data,
                    races: FiscalServices.shared.liveResultsService(),
                    follows: session.repositories.follows)
            ) {
                ShareScreen()
            }
        case .support: SupportDestination()
        case .liked: FeedLikedScreen()
        case .content(let content):
            ModelHost(ContentDetailModel(content: content)) { ContentDetailScreen() }
        case .highlight(let id):
            ModelHost(ContentDetailModel(highlightID: id, service: data)) { ContentDetailScreen() }
        }
    }
}

private struct SupportDestination: View {
    @Environment(SupportContext.self) private var support
    @Environment(SessionModel.self) private var session

    var body: some View {
        let data = FiscalServices.shared.publicData()
        ModelHost(
            SupportModel(context: support, service: data, follows: session.repositories.follows)
        ) {
            SupportScreen(service: data, follows: session.repositories.follows)
        }
    }
}

private struct MoneySpendersDestination: View {
    @Environment(MoneyModel.self) private var money
    let title: String
    let spenders: [MoneyPlaces.Spender]
    let year: Int?

    var body: some View {
        MoneySpendersScreen(title: title, spenders: spenders, year: year)
            .task { await money.load() }
    }
}

private struct AwaitingDestination: View {
    @Environment(MemoryModel.self) private var memory

    var body: some View {
        AwaitingScreen()
            .task { await memory.load() }
    }
}

private struct ArtistsDestination: View {
    var body: some View {
        ModelHost(ArtistsModel()) { ArtistsScreen() }
    }
}
