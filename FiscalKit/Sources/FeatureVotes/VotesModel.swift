import FeatureCore
import FiscalDomain
import Foundation
import Observation

@MainActor @Observable
public final class VotesModel {
    public private(set) var votes: [VoteSummary] = []
    public private(set) var phase: PublicDataPhase = .idle
    @ObservationIgnored private let service: (any PublicDataService)?

    public init(service: (any PublicDataService)?) {
        self.service = service
    }

    public var isEmpty: Bool { votes.isEmpty }

    public func detail(for vote: VoteSummary) -> String {
        let date = vote.date.date().formatted(
            Date.FormatStyle(date: .abbreviated, time: .omitted, locale: .app))
        return [vote.house.title, date, vote.result].compactMap(\.self).joined(separator: " · ")
    }

    public func load() async {
        if votes.isEmpty { phase = .loading }
        phase = await PublicDataPhase.settle(after: phase) {
            guard let service else { throw PublicDataError.unavailable }
            votes = try await service.recentVotes()
        }
    }
}
