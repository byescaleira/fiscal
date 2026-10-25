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

        public var header: String { "\(title) · \(people.count)" }
    }

    public private(set) var followed: [FollowedPerson] = []
    public private(set) var hasLoaded = false
    public private(set) var place: Place?
    public private(set) var representatives: PlaceRepresentatives?
    public private(set) var phase: PublicDataPhase = .idle
    public private(set) var places: [Place] = []
    public private(set) var placesPhase: PublicDataPhase = .idle
    public var query = ""
    public var isChoosingPlace = false
    public var error: FiscalError?
    @ObservationIgnored private let service: (any PublicDataService)?
    @ObservationIgnored private let follows: (any FollowRepository)?
    @ObservationIgnored private let memory: MinePlaceMemory

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
        return Office.allCases.compactMap { office in
            let matching = representatives.groups.filter { $0.office == office }
            let people = MineModel.alphabetical(matching.flatMap(\.people))
            guard let first = matching.first, !people.isEmpty else { return nil }
            return OfficeGroup(office: office, title: first.title, people: people)
        }
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
                    "Pick your state or city to see who represents you, from the president to the state assembly."
            )
        }
        guard !place.isState else {
            return String(appLocalized: "From the president to the state assembly")
        }
        let state = representatives?.name ?? place.uf.uppercased()
        return String(appLocalized: "\(state) · from the president to the state assembly")
    }

    public var ufText: String? { place.map { $0.uf.uppercased() } }

    public var countText: String { PublicFormat.number(representativeCount) }

    public var cityNote: String? {
        guard let place, !place.isState else { return nil }
        return String(
            appLocalized:
                "Mayors and city councilors come after version 1.0. For now, Fiscal shows who represents \(place.name) in the state and in Brasília."
        )
    }

    public var sourceText: String? {
        representatives.flatMap { SourceFootnote.text($0.sources) }
    }

    public var shareRoute: Route? {
        guard let uf = representatives?.uf, !groups.isEmpty else { return nil }
        return .share(.representatives(uf: uf))
    }

    public func detail(for person: FollowedPerson) -> String {
        let place = person.card.uf == "br" ? "" : " · \(person.card.uf.uppercased())"
        return "\(person.card.office.title) · \(person.card.party)\(place)"
    }

    public func status(of card: PersonCard) -> String? {
        card.status == .inOffice ? nil : card.status.title
    }

    public func accessibilityLabel(for card: PersonCard) -> String {
        let parts = [card.name, card.party, card.office.title, status(of: card)]
        return parts.compactMap(\.self).joined(separator: ", ")
    }

    public func load() async {
        await loadFollowed()
        await loadPlace()
    }

    public func loadFollowed() async {
        do {
            let list = try await follows?.followed() ?? []
            followed = list.sorted {
                $0.card.name.localizedStandardCompare($1.card.name) == .orderedAscending
            }
            hasLoaded = true
        } catch is CancellationError {} catch {
            self.error = error as? FiscalError ?? .onFetch
        }
    }

    public func loadPlace() async {
        guard let code = memory.code else {
            place = nil
            representatives = nil
            phase = .idle
            return
        }
        if representatives == nil { phase = .loading }
        phase = await PublicDataPhase.settle(after: phase) {
            guard let service else { throw PublicDataError.unavailable }
            let resolved = try await resolve(code, service: service)
            representatives = try await service.representatives(uf: resolved.uf)
            place = resolved
        }
    }

    public func choose(_ choice: Place) async {
        memory.code = choice.code
        place = nil
        representatives = nil
        isChoosingPlace = false
        query = ""
        await loadPlace()
    }

    public func forgetPlace() {
        memory.code = nil
        place = nil
        representatives = nil
        phase = .idle
    }

    public func loadPlaces() async {
        guard places.isEmpty else { return }
        placesPhase = .loading
        placesPhase = await PublicDataPhase.settle(after: placesPhase) {
            guard let service else { throw PublicDataError.unavailable }
            places = try await service.places()
        }
    }

    private func resolve(_ code: String, service: any PublicDataService) async throws -> Place {
        if code.count == 2 {
            return Place(code: code, name: code.uppercased(), uf: code)
        }
        if places.isEmpty { places = try await service.places() }
        guard let match = places.first(where: { $0.code == code }) else {
            throw PublicDataError.notFound
        }
        return match
    }

    static func alphabetical(_ people: [PersonCard]) -> [PersonCard] {
        var seen = Set<String>()
        return people.filter { seen.insert($0.slug).inserted }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
