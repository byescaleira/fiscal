import FeatureCore
import FiscalDomain
import Foundation
import Observation

@MainActor @Observable
public final class CompareModel {
    public struct Cell: Identifiable, Equatable {
        public let id: String
        public let name: String
        public let value: String
    }

    public struct Row: Identifiable, Equatable {
        public let id: String
        public let title: String
        public let cells: [Cell]
    }

    public let slugs: [String]
    public private(set) var profiles: [Profile] = []
    public private(set) var phase: PublicDataPhase = .idle
    @ObservationIgnored private let service: (any PublicDataService)?

    public init(slugs: [String], service: (any PublicDataService)? = nil) {
        self.slugs = slugs
        self.service = service
        phase = slugs.count >= 2 ? .idle : .loaded
    }

    public var canCompare: Bool { slugs.count >= 2 }

    public var isEmpty: Bool { !canCompare || profiles.count < 2 }

    public var rows: [Row] {
        guard !isEmpty else { return [] }
        return [
            row("attendance", String(appLocalized: "Attendance")) {
                PublicFormat.percent($0.numbers.attendance?.fraction)
            },
            row("proposals", String(appLocalized: "Proposals")) {
                PublicFormat.number($0.numbers.proposals)
            },
            row("quota", String(appLocalized: "Office allowance")) {
                PublicFormat.money(cents: $0.numbers.quotaCents)
            },
        ]
    }

    private func row(_ id: String, _ title: String, value: (Profile) -> String) -> Row {
        Row(
            id: id, title: title,
            cells: profiles.map { Cell(id: $0.slug, name: $0.name, value: value($0)) })
    }

    public func load() async {
        guard canCompare else { return }
        if profiles.isEmpty { phase = .loading }
        phase = await PublicDataPhase.settle(after: phase) {
            guard let service else { throw PublicDataError.unavailable }
            var loaded: [Profile] = []
            for slug in slugs { loaded.append(try await service.profile(slug: slug)) }
            profiles = loaded
        }
    }
}
