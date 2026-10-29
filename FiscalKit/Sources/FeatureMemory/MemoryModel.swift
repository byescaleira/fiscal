import FeatureCore
import FiscalDomain
import Foundation
import Observation

@MainActor @Observable
public final class MemoryModel {
    public static let republicStart = 1_889

    public private(set) var phase: PublicDataPhase = .idle
    public private(set) var history: ElectionHistory?
    public private(set) var timeline: PoliticalTimeline?
    public private(set) var study: StudyCatalog?
    public private(set) var liveCounted: Double?
    public private(set) var awaiting: [PersonCard] = []
    @ObservationIgnored private let service: (any PublicDataService)?
    @ObservationIgnored private let races: (any LiveResultsService)?
    @ObservationIgnored private let now: @Sendable () -> Date

    public init(
        service: (any PublicDataService)?, races: (any LiveResultsService)? = nil,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.service = service
        self.races = races
        self.now = now
    }

    var schedule: [ScheduledElection] { ElectionSchedule.elections(now: now()) }

    var republicYears: Int {
        Calendar(identifier: .gregorian).component(.year, from: now()) - Self.republicStart
    }

    var presidential: [PastRaceSummary] {
        (history?.races ?? []).filter { $0.office == .president }.sorted { $0.year > $1.year }
    }

    var otherYears: [Int] {
        let withPresident = Set(presidential.map(\.year))
        return Set((history?.races ?? []).map(\.year)).subtracting(withPresident).sorted(by: >)
    }

    var periods: [PoliticalPeriod] { timeline?.periods ?? [] }

    var guides: [StudyGuide] { study?.guides ?? [] }

    var isEmpty: Bool { history == nil && timeline == nil && study == nil }

    var electionFooter: String {
        String(
            appLocalized:
                "Source: TSE open data, results by municipality and zone. Percentages over valid votes."
        )
    }

    var periodsFooter: String {
        String(
            appLocalized:
                "Each fact carries its source: CPDOC/FGV, Planalto, Senate, Chamber and reference books. Fiscal adds no opinion."
        )
    }

    public func load() async {
        guard let service else {
            phase = .failed(.unavailable)
            return
        }
        if isEmpty { phase = .loading }
        phase = await PublicDataPhase.settle(after: phase) {
            async let elections = try? service.electionHistory()
            async let periods = try? service.politicalTimeline()
            async let guides = try? service.studyCatalog()
            async let people = try? service.people()
            let loaded = await (elections, periods, guides, people)
            history = loaded.0 ?? nil
            timeline = loaded.1 ?? nil
            study = loaded.2 ?? nil
            awaiting = (loaded.3 ?? [])
                .filter { $0.status == .electedAwaiting }
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            if isEmpty { throw PublicDataError.notFound }
        }
        await loadLiveCount()
    }

    private func loadLiveCount() async {
        guard schedule.contains(where: { $0.liveRound != nil }), let races,
            let list = try? await races.races(), !list.isEmpty
        else { return }
        let lead = list.first { $0.office == .president } ?? list[0]
        liveCounted = lead.sections.percent / 100
    }

    func winner(of race: PastRaceSummary) -> PastPick? {
        race.finalRound?.leaders.first { $0.elected } ?? race.finalRound?.leaders.first
    }

    func runnerUp(of race: PastRaceSummary) -> PastPick? {
        guard let round = race.finalRound else { return nil }
        let won = winner(of: race)
        return round.leaders.first { $0 != won }
    }

    var liveCountedText: String? {
        liveCounted.map { String(appLocalized: "Polls counted: \(PublicFormat.percent($0))") }
    }

    func roundLine(_ race: PastRaceSummary) -> String {
        guard let round = race.finalRound else { return PublicFormat.missing }
        let label = MemoryText.round(round.round, total: race.rounds.count)
        return "\(label) · \(MemoryText.day(round.day))"
    }

    func turnoutLine(_ race: PastRaceSummary) -> String? {
        guard let turnout = race.finalRound?.turnout else { return nil }
        return String(appLocalized: "Turnout \(MemoryText.shortPercent(turnout))")
    }

    func accessibility(_ race: PastRaceSummary) -> String {
        guard let won = winner(of: race) else { return String(race.year) }
        return String(
            appLocalized:
                "\(String(race.year)), \(MemoryText.name(won.ballotName)), \(won.party), \(MemoryText.percent(won.share))"
        )
    }
}
