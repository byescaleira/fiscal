import FeatureCore
import FiscalData
import FiscalDomain
import Foundation

#if canImport(WidgetKit)
    import WidgetKit
#endif

@MainActor
public final class IntegrationCenter {
    public static let shared = IntegrationCenter()
    public static var onPeopleIndexed: (@MainActor () -> Void)?

    private let recent: RecentPeople
    private let place: HomePlace
    private let defaults: UserDefaults
    private let indexer: any PeopleIndexing
    private let service: @MainActor () -> (any PublicDataService)?
    private var visible: Set<String> = []

    init(
        indexer: any PeopleIndexing = SpotlightPeopleIndex(),
        defaults: UserDefaults = .standard,
        place: HomePlace = HomePlace(),
        service: @escaping @MainActor () -> (any PublicDataService)? = {
            FiscalServices.shared.publicData()
        }
    ) {
        self.indexer = indexer
        self.defaults = defaults
        self.place = place
        self.service = service
        recent = RecentPeople(defaults: defaults)
    }

    @discardableResult
    func syncWidgets() -> Bool {
        var changed = place.save(uf: HomePlace.chosenUF(in: defaults))
        #if DEBUG
            let scenario = PublicDataScenario.named(
                defaults.string(forKey: PublicDataScenario.launchKey))
            changed = place.save(scenario: scenario?.rawValue) || changed
        #endif
        if changed { reloadWidgets() }
        return changed
    }

    func reloadWidgets() {
        #if canImport(WidgetKit)
            WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    func observe(routes: [Route], follows: (any FollowRepository)?) async {
        let slugs = RecentPeople.personSlugs(in: routes)
        let opened = slugs.filter { !visible.contains($0) }
        visible = Set(slugs)
        guard !opened.isEmpty else { return }
        var changed = false
        for slug in opened { changed = recent.record(slug) || changed }
        if changed { await refreshIndex(follows: follows) }
    }

    func refreshIndex(follows: (any FollowRepository)?) async {
        let followed = (try? await follows?.followed())?.map(\.card) ?? []
        let slugs = recent.slugs
        var viewed: [PersonCard] = []
        if let service = service(), !slugs.isEmpty {
            viewed = (try? await IntegrationActions(service: service).people(slugs: slugs)) ?? []
        }
        await indexer.replace(with: SpotlightPerson.entries(followed: followed, recent: viewed))
        Self.onPeopleIndexed?()
    }
}
