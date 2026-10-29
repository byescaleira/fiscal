import FeatureCore
import FeatureLens
import FeatureLiveResults
import FeatureMemory
import FeatureMine
import FeatureMoney
import FeatureProfile
import FeatureSearch
import FeatureSettings
import FeatureShare
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
                    slug: slug, service: data, follows: session.repositories.follows,
                    lens: session.repositories.lens)
            ) {
                ProfileScreen()
            }
        case .vote(let id):
            ModelHost(
                VoteDetailModel(
                    id: id, service: data, lens: session.repositories.lens,
                    homeUF: HomePlace.chosenUF(in: .standard))
            ) {
                VoteDetailScreen()
            }
        case .expenses(let slug, let year):
            ModelHost(ExpensesModel(slug: slug, year: year, service: data)) { ExpensesScreen() }
        case .compare(let slugs):
            ModelHost(CompareModel(slugs: slugs, service: data)) { CompareScreen() }
        case .races: LiveResultsScreen()
        case .race(let id): RaceDetailScreen(raceID: id)
        case .roster(let title, let people):
            MineRosterScreen(roster: MineRoster(title: title, people: people))
        case .spenders(let title, let spenders, let year):
            ModelHost(MoneyModel(service: data, lens: session.repositories.lens)) {
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
        case .lens: LensDestination()
        case .artists: ArtistsDestination()
        case .settings:
            SettingsScreen(service: data) {
                LensDestination()
            } artists: {
                ArtistsDestination()
            }
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
    @Environment(SessionModel.self) private var session

    var body: some View {
        ModelHost(
            LensModel(
                context: lens, service: FiscalServices.shared.publicData(),
                icons: SystemAppIconSwitcher(), follows: session.repositories.follows)
        ) {
            LensScreen()
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
    @Environment(SessionModel.self) private var session

    var body: some View {
        ModelHost(ArtistsModel(lens: session.repositories.lens)) { ArtistsScreen() }
    }
}
