import FeatureCore
import FiscalDomain
import Foundation
import Observation

@MainActor @Observable
public final class FollowingModel {
    public nonisolated static let inviteKey = "fiscal.share.followingInviteDismissed"
    nonisolated static let suggestionLimit = 8
    nonisolated static let suggestionOrder: [Office] = [
        .president, .governor, .senator, .mayor, .federalDeputy, .stateDeputy, .vicePresident,
        .viceGovernor, .viceMayor, .cityCouncilor,
    ]

    public private(set) var followed: [FollowedPerson] = []
    public private(set) var hasLoaded = false
    public var error: FiscalError?
    @ObservationIgnored private let service: (any PublicDataService)?
    @ObservationIgnored private let follows: (any FollowRepository)?
    @ObservationIgnored private let inviteDefaults: UserDefaults
    private let place: RegionModel
    private var isInviteDismissed: Bool

    public init(
        service: (any PublicDataService)? = nil, follows: (any FollowRepository)?,
        memory: RegionPlaceMemory = RegionPlaceMemory(), inviteDefaults: UserDefaults = .standard
    ) {
        self.service = service
        self.follows = follows
        self.inviteDefaults = inviteDefaults
        place = RegionModel(service: service, memory: memory)
        isInviteDismissed = inviteDefaults.bool(forKey: Self.inviteKey)
    }

    public var isEmpty: Bool { followed.isEmpty }

    public var cards: [PersonCard] { followed.map(\.card) }

    public var hasPlace: Bool { place.hasPlace }

    public var suggestions: [PersonCard] {
        let followedSlugs = Set(followed.map(\.card.slug))
        var included = Set<String>()
        let representatives = place.groups.flatMap(\.people).enumerated().sorted { lhs, rhs in
            (Self.rank(lhs.element.office), lhs.offset) < (
                Self.rank(rhs.element.office), rhs.offset
            )
        }
        .map(\.element)
        let pool = representatives.filter {
            !followedSlugs.contains($0.slug) && included.insert($0.slug).inserted
        }
        return Array(pool.prefix(Self.suggestionLimit))
    }

    public var showsInvite: Bool { !followed.isEmpty && !isInviteDismissed }

    public var inviteRoute: Route { .share(.following) }

    public func dismissInvite() {
        isInviteDismissed = true
        inviteDefaults.set(true, forKey: Self.inviteKey)
    }

    public func load() async {
        await loadFollowed()
        await place.loadPlace()
    }

    private func loadFollowed() async {
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

    nonisolated static func rank(_ office: Office) -> Int {
        suggestionOrder.firstIndex(of: office) ?? suggestionOrder.count
    }
}
