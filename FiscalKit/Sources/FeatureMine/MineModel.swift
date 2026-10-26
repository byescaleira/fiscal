import FeatureCore
import FiscalDomain
import Foundation
import Observation

@MainActor @Observable
public final class MineModel {
    public struct OfficeGroup: Identifiable, Equatable {
        public let office: Office
        public let title: String
        public let people: [PersonCard]

        public var id: Office { office }

        public var isSingle: Bool { people.count == 1 }

        public var showsOffice: Bool { isSingle || Set(people.map(\.office)).count > 1 }

        public var isProminent: Bool { isSingle || office == .mayor }

        public var header: String { "\(title) · \(people.count)" }
    }

    public private(set) var followed: [FollowedPerson] = []
    public private(set) var hasLoaded = false
    public private(set) var place: Place?
    public private(set) var representatives: PlaceRepresentatives?
    public private(set) var cityRepresentatives: PlaceRepresentatives?
    public private(set) var phase: PublicDataPhase = .idle
    public private(set) var places: [Place] = []
    public private(set) var placesPhase: PublicDataPhase = .idle
    public var query = ""
    public var isChoosingPlace = false
    public var error: FiscalError?
    @ObservationIgnored private let service: (any PublicDataService)?
    @ObservationIgnored private let follows: (any FollowRepository)?
    @ObservationIgnored private let memory: MinePlaceMemory
    @ObservationIgnored var searchNames: [String: String] = [:]

    public init(
        service: (any PublicDataService)? = nil, follows: (any FollowRepository)?,
        memory: MinePlaceMemory = MinePlaceMemory()
    ) {
        self.service = service
        self.follows = follows
        self.memory = memory
    }

    public var isEmpty: Bool { followed.isEmpty }

    public var hasPlace: Bool { memory.code != nil }

    public var groups: [OfficeGroup] {
        guard let representatives else { return [] }
        let city = (cityRepresentatives?.groups ?? []).compactMap { group -> OfficeGroup? in
            let people =
                group.office == .cityCouncilor
                ? MineModel.alphabetical(group.people) : MineModel.hall(group.people)
            guard !people.isEmpty else { return nil }
            return OfficeGroup(office: group.office, title: group.title, people: people)
        }
        let state = Office.allCases.filter { !$0.isMunicipal }.compactMap {
            office -> OfficeGroup? in
            let matching = representatives.groups.filter { $0.office == office }
            let people = MineModel.alphabetical(matching.flatMap(\.people))
            guard let first = matching.first, !people.isEmpty else { return nil }
            return OfficeGroup(office: office, title: first.title, people: people)
        }
        return city + state
    }

    public var representativeCount: Int {
        Set(groups.flatMap { $0.people.map(\.slug) }).count
    }

    public var hasNoRepresentatives: Bool { phase == .loaded && groups.isEmpty }

    public var placeTitle: String {
        guard let place else { return String(appLocalized: "Who represents you") }
        return place.isState ? representatives?.name ?? place.uf.uppercased() : place.name
    }

    public var placeKicker: String {
        guard let place else { return String(appLocalized: "MY REPRESENTATIVES") }
        return place.isState
            ? String(appLocalized: "YOUR STATE") : String(appLocalized: "YOUR CITY")
    }

    public var placeDetail: String {
        guard let place else {
            return String(
                appLocalized:
                    "Pick your state or city to see who represents you, from the city councilor to the president."
            )
        }
        guard !place.isState else {
            return String(appLocalized: "From the president to the state assembly")
        }
        let state = representatives?.name ?? place.uf.uppercased()
        return String(appLocalized: "\(state) · from the city councilor to the president")
    }

    public var ufText: String? { place.map { $0.uf.uppercased() } }

    public var countText: String { PublicFormat.number(representativeCount) }

    public var cityNote: String? {
        guard let place, !place.isState, phase == .loaded else { return nil }
        guard let city = cityRepresentatives else {
            return String(
                appLocalized:
                    "The list of the mayor and city councilors of \(place.name) isn't published yet."
            )
        }
        return city.note
    }

    public var sourceText: String? {
        guard let representatives else { return nil }
        var seen = Set<String>()
        let sources = ((cityRepresentatives?.sources ?? []) + representatives.sources)
            .filter { seen.insert($0.id).inserted }
        return SourceFootnote.text(sources)
    }

    public var shareRoute: Route? {
        guard let uf = representatives?.uf, !groups.isEmpty else { return nil }
        return .share(.representatives(uf: uf))
    }

    public func detail(for person: FollowedPerson) -> String {
        let place = person.card.uf == "br" ? "" : " · \(person.card.uf.uppercased())"
        return "\(person.card.officeTitle) · \(person.card.party)\(place)"
    }

    public func status(of card: PersonCard) -> String? {
        card.status == .inOffice ? nil : card.status.title
    }

    public func accessibilityLabel(for card: PersonCard) -> String {
        let parts = [card.name, card.party, card.officeTitle, status(of: card)]
        return parts.compactMap(\.self).joined(separator: ", ")
    }

    public func load() async {
        await loadFollowed()
        await loadPlace()
    }

    public func loadFollowed() async {
        do {
            let stored = try await follows?.followed() ?? []
            let list = await withGenders(stored)
            followed = list.sorted {
                $0.card.name.localizedStandardCompare($1.card.name) == .orderedAscending
            }
            hasLoaded = true
        } catch is CancellationError {} catch {
            self.error = error as? FiscalError ?? .onFetch
        }
    }

    private func withGenders(_ list: [FollowedPerson]) async -> [FollowedPerson] {
        guard list.contains(where: { $0.card.gender == nil }),
            let people = try? await service?.people()
        else { return list }
        let genders = Dictionary(
            people.compactMap { card in card.gender.map { (card.slug, $0) } },
            uniquingKeysWith: { first, _ in first })
        return list.map { person in
            guard person.card.gender == nil, let gender = genders[person.card.slug] else {
                return person
            }
            return FollowedPerson(
                card: person.card.with(gender: gender), followedAt: person.followedAt)
        }
    }

    public func loadPlace() async {
        guard let code = memory.code else {
            place = nil
            representatives = nil
            cityRepresentatives = nil
            phase = .idle
            return
        }
        if representatives == nil { phase = .loading }
        phase = await PublicDataPhase.settle(after: phase) {
            guard let service else { throw PublicDataError.unavailable }
            let resolved = try await resolve(code, service: service)
            async let state = service.representatives(uf: resolved.uf)
            async let city: PlaceRepresentatives? =
                resolved.isState ? nil : service.cityRepresentatives(code: resolved.code)
            let (stateList, cityList) = try await (state, city)
            representatives = stateList
            cityRepresentatives = cityList
            place = resolved
        }
    }

    public func choose(_ choice: Place) async {
        memory.code = choice.code
        place = nil
        representatives = nil
        cityRepresentatives = nil
        isChoosingPlace = false
        query = ""
        await loadPlace()
    }

    public func forgetPlace() {
        memory.code = nil
        place = nil
        representatives = nil
        cityRepresentatives = nil
        phase = .idle
    }

    public func loadPlaces() async {
        guard places.isEmpty else { return }
        placesPhase = .loading
        placesPhase = await PublicDataPhase.settle(after: placesPhase) {
            guard let service else { throw PublicDataError.unavailable }
            setPlaces(try await service.places())
        }
    }

    private func resolve(_ code: String, service: any PublicDataService) async throws -> Place {
        if code.count == 2 {
            return Place(code: code, name: code.uppercased(), uf: code)
        }
        if places.isEmpty { setPlaces(try await service.places()) }
        guard let match = places.first(where: { $0.code == code }) else {
            throw PublicDataError.notFound
        }
        return match
    }

    func setPlaces(_ list: [Place]) {
        searchNames = Dictionary(
            list.map { ($0.code, Self.normalized($0.name)) },
            uniquingKeysWith: { first, _ in first })
        places = list
    }

    static func hall(_ people: [PersonCard]) -> [PersonCard] {
        var seen = Set<String>()
        let unique = people.filter { seen.insert($0.slug).inserted }
        return unique.filter { $0.office == .mayor } + unique.filter { $0.office != .mayor }
    }

    static func alphabetical(_ people: [PersonCard]) -> [PersonCard] {
        var seen = Set<String>()
        return people.filter { seen.insert($0.slug).inserted }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
