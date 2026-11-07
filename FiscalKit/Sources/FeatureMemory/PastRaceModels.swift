import FeatureCore
import FiscalDomain
import Foundation
import Observation

@MainActor @Observable
public final class ElectionYearModel {
    public let year: Int
    public private(set) var phase: PublicDataPhase = .idle
    public private(set) var history: ElectionHistory?
    public private(set) var president: PastRace?
    public var round: Int?
    @ObservationIgnored private let service: (any PublicDataService)?
    @ObservationIgnored private let requests = PublicDataRequests()

    public init(year: Int, service: (any PublicDataService)?) {
        self.year = year
        self.service = service
    }

    var races: [PastRaceSummary] { (history?.races ?? []).filter { $0.year == year } }

    var governors: [PastRaceSummary] {
        races.filter { $0.office == .governor }.sorted { $0.scopeName < $1.scopeName }
    }

    var senators: [PastRaceSummary] {
        races.filter { $0.office == .senator }.sorted { $0.scopeName < $1.scopeName }
    }

    var gaps: [ElectionGap] { (history?.gaps ?? []).filter { $0.year == year } }

    var breakdown: PastRoundBreakdown? {
        guard let president else { return nil }
        let chosen = president.rounds.first { $0.round == round } ?? president.rounds.last
        return chosen.map { PastRoundBreakdown(race: president, round: $0) }
    }

    var isEmpty: Bool { races.isEmpty }

    var roundSubtitle: String { breakdown?.roundLine ?? "" }

    var title: String { String(appLocalized: "Elections \(String(year))") }

    var sourceLine: String {
        let refs = (history?.sources ?? []).filter { $0.id == "tse-\(year)" }
        return MemoryText.sources(refs) ?? String(appLocalized: "Source: TSE open data")
    }

    public func load() async {
        guard let service else {
            phase = .failed(.unavailable)
            return
        }
        if isEmpty { phase = .loading }
        phase = await PublicDataPhase.settle(after: phase, in: requests) {
            let history = try await service.electionHistory()
            let summary = history?.races.first { $0.year == year && $0.office == .president }
            let race: PastRace? =
                if let summary { try await service.pastRace(id: summary.id) } else { president }
            return (history: history, president: race)
        } apply: { loaded in
            history = loaded.history
            president = loaded.president
        }
    }

    func winner(_ race: PastRaceSummary) -> [PastPick] {
        let elected = race.elected
        return elected.isEmpty ? Array(race.finalRound?.leaders.prefix(1) ?? []) : elected
    }

    func detail(_ race: PastRaceSummary) -> String {
        let rounds =
            race.rounds.count > 1
            ? String(appLocalized: "Decided in round 2")
            : String(appLocalized: "Decided in round 1")
        guard let turnout = race.finalRound?.turnout else { return rounds }
        return "\(rounds) · \(String(appLocalized: "Turnout \(MemoryText.shortPercent(turnout))"))"
    }
}

@MainActor @Observable
public final class PastRaceModel {
    public let id: String
    public private(set) var phase: PublicDataPhase = .idle
    public private(set) var race: PastRace?
    public var round: Int?
    @ObservationIgnored private let service: (any PublicDataService)?
    @ObservationIgnored private let requests = PublicDataRequests()

    public init(id: String, service: (any PublicDataService)?) {
        self.id = id
        self.service = service
    }

    var breakdown: PastRoundBreakdown? {
        guard let race else { return nil }
        let chosen = race.rounds.first { $0.round == round } ?? race.rounds.last
        return chosen.map { PastRoundBreakdown(race: race, round: $0) }
    }

    var roundSubtitle: String { breakdown?.roundLine ?? "" }

    var title: String {
        guard let race else { return String(appLocalized: "Result") }
        return
            "\(MemoryText.office(race.office, seats: race.seats)) · \(race.scope.uppercased(with: .app)) · \(String(race.year))"
    }

    public func load() async {
        guard let service else {
            phase = .failed(.unavailable)
            return
        }
        if race == nil { phase = .loading }
        phase = await PublicDataPhase.settle(after: phase, in: requests) {
            guard let loaded = try await service.pastRace(id: id) else {
                throw PublicDataError.notFound
            }
            return loaded
        } apply: { loaded in
            race = loaded
        }
    }
}
