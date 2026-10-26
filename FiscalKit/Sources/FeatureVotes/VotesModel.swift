import FeatureCore
import FiscalDomain
import Foundation
import Observation

@MainActor @Observable
public final class VotesModel {
    public enum HouseFilter: String, CaseIterable, Identifiable, Sendable {
        case all, camara, senado

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .all: String(appLocalized: "Both Houses")
            case .camara: String(appLocalized: "Chamber")
            case .senado: String(appLocalized: "Senate")
            }
        }

        func matches(_ house: House) -> Bool {
            switch self {
            case .all: true
            case .camara: house == .camara
            case .senado: house == .senado
            }
        }
    }

    public struct Day: Identifiable, Equatable {
        public let id: CalendarDay
        public let votes: [VoteSummary]
    }

    public static let highlightLimit = 3

    public private(set) var votes: [VoteSummary] = []
    public private(set) var agenda: Agenda?
    public private(set) var lens: Lens?
    public private(set) var phase: PublicDataPhase = .idle
    public var house: HouseFilter = .all
    public var theme: Theme?
    @ObservationIgnored private let service: (any PublicDataService)?
    @ObservationIgnored private let lensRepository: (any LensRepository)?
    @ObservationIgnored let now: @Sendable () -> Date

    public init(
        service: (any PublicDataService)?, lens: (any LensRepository)? = nil,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.service = service
        lensRepository = lens
        self.now = now
    }

    public var isEmpty: Bool { votes.isEmpty && agendaHouses.isEmpty }

    public var hasFilter: Bool { activeFilterCount > 0 }

    public var activeFilterCount: Int {
        (house == .all ? 0 : 1) + (theme == nil ? 0 : 1)
    }

    public var filtered: [VoteSummary] {
        votes.filter { vote in
            house.matches(vote.house) && (theme.map { vote.themes.contains($0) } ?? true)
        }
    }

    public var days: [Day] {
        var order: [CalendarDay] = []
        var groups: [CalendarDay: [VoteSummary]] = [:]
        for vote in filtered {
            if groups[vote.date] == nil { order.append(vote.date) }
            groups[vote.date, default: []].append(vote)
        }
        return order.sorted(by: >).map { Day(id: $0, votes: groups[$0] ?? []) }
    }

    public var themeChoices: [Theme] {
        let used = Set(votes.flatMap(\.themes))
        let present = Theme.allCases.filter(used.contains)
        return lens?.ordered(present) ?? present
    }

    public var showsLensBadge: Bool { !(lens?.themes.isEmpty ?? true) }

    public var lensThemeChoices: [Theme] { themeChoices.filter(isLensTheme) }

    public var otherThemeChoices: [Theme] { themeChoices.filter { !isLensTheme($0) } }

    public func isLensTheme(_ theme: Theme) -> Bool { lens?.contains(theme) ?? false }

    public var highlights: [VoteSummary] {
        guard let lens, !lens.themes.isEmpty, !hasFilter else { return [] }
        let matching = votes.filter { vote in vote.themes.contains { lens.contains($0) } }
        return Array(matching.prefix(Self.highlightLimit))
    }

    public func lensTheme(of vote: VoteSummary) -> Theme? {
        guard let lens else { return vote.themes.first }
        return lens.ordered(vote.themes).first
    }

    public var agendaHouses: [Agenda.HouseDay] {
        agenda?.houses.filter { $0.inSession || !$0.items.isEmpty } ?? []
    }

    public var isAgendaToday: Bool {
        agenda.map { $0.date == CalendarDay(now()) } ?? false
    }

    public func clearFilters() {
        house = .all
        theme = nil
    }

    public func load() async {
        if votes.isEmpty { phase = .loading }
        phase = await PublicDataPhase.settle(after: phase) {
            lens = try? await lensRepository?.lens()
            guard let service else { throw PublicDataError.unavailable }
            votes = try await service.recentVotes()
            agenda = try? await service.agenda()
        }
    }
}
