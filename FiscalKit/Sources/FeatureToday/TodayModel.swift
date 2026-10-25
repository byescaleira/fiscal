import FeatureCore
import FiscalDomain
import Foundation
import Observation

@MainActor @Observable
public final class TodayModel {
    public private(set) var digest: TodayDigest?
    public private(set) var lens: Lens?
    public private(set) var phase: PublicDataPhase = .idle
    @ObservationIgnored private let service: (any PublicDataService)?
    @ObservationIgnored private let lensRepository: (any LensRepository)?

    public init(service: (any PublicDataService)?, lens: (any LensRepository)? = nil) {
        self.service = service
        lensRepository = lens
    }

    public var events: [TodayDigest.Event] {
        guard let digest else { return [] }
        guard let lens, !lens.themes.isEmpty else { return digest.events }
        return digest.events.enumerated()
            .sorted { lhs, rhs in
                (rank(lhs.element, in: lens), lhs.offset) < (
                    rank(rhs.element, in: lens), rhs.offset
                )
            }
            .map(\.element)
    }

    public var isEmpty: Bool { events.isEmpty }

    public var sources: [Source] { digest?.sources ?? [] }

    public func load() async {
        if digest == nil { phase = .loading }
        phase = await PublicDataPhase.settle(after: phase) {
            lens = try? await lensRepository?.lens()
            guard let service else { throw PublicDataError.unavailable }
            digest = try await service.today()
        }
    }

    private func rank(_ event: TodayDigest.Event, in lens: Lens) -> Int {
        event.themes.compactMap { lens.themes.firstIndex(of: $0) }.min() ?? lens.themes.count
    }
}

extension TodayDigest.Event {
    var symbol: String {
        switch kind {
        case .vote: "checkmark.square"
        case .session: "building.columns"
        case .race: "checkmark.seal"
        case .law: "doc.text"
        }
    }
}
