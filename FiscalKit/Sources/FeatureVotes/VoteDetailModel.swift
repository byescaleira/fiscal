import FeatureCore
import FiscalDomain
import Foundation
import Observation

@MainActor @Observable
public final class VoteDetailModel {
    public struct Count: Identifiable, Equatable {
        public let id: String
        public let title: String
        public let value: String
    }

    public let id: String
    public private(set) var detail: VoteDetail?
    public private(set) var phase: PublicDataPhase = .idle
    @ObservationIgnored private let service: (any PublicDataService)?

    public init(id: String, service: (any PublicDataService)?) {
        self.id = id
        self.service = service
    }

    public var isEmpty: Bool { detail == nil }

    public var title: String { detail?.vote.proposition ?? String(appLocalized: "Vote") }

    public var counts: [Count] {
        guard let tally = detail?.vote.tally else { return [] }
        return [
            Count(
                id: "yes", title: String(appLocalized: "Yes"), value: PublicFormat.number(tally.yes)
            ),
            Count(
                id: "no", title: String(appLocalized: "No"), value: PublicFormat.number(tally.no)),
            Count(
                id: "others", title: String(appLocalized: "Other votes"),
                value: PublicFormat.number(tally.others)),
        ]
    }

    public func load() async {
        if detail == nil { phase = .loading }
        phase = await PublicDataPhase.settle(after: phase) {
            guard let service else { throw PublicDataError.unavailable }
            detail = try await service.vote(id: id)
        }
    }
}
