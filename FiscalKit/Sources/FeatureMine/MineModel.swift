import FeatureCore
import FiscalDomain
import Foundation
import Observation

@MainActor @Observable
public final class MineModel {
    public private(set) var followed: [FollowedPerson] = []
    public private(set) var hasLoaded = false
    public var error: FiscalError?
    @ObservationIgnored private let follows: (any FollowRepository)?

    public init(follows: (any FollowRepository)?) {
        self.follows = follows
    }

    public var isEmpty: Bool { followed.isEmpty }

    public func detail(for person: FollowedPerson) -> String {
        let place = person.card.uf == "br" ? "" : " · \(person.card.uf.uppercased())"
        return "\(person.card.office.title) · \(person.card.party)\(place)"
    }

    public func load() async {
        do {
            followed = try await follows?.followed() ?? []
            hasLoaded = true
        } catch is CancellationError {} catch {
            self.error = error as? FiscalError ?? .onFetch
        }
    }
}
