import FeatureCore
import FiscalDomain
import Foundation
import Observation

enum RaceDetailPhase {
    case loading, unavailable
    case ready(RaceSummary)
}

@MainActor @Observable
public final class LiveResultsModel {
    public private(set) var races: [Race] = []
    public private(set) var hasLoaded = false
    public private(set) var isOffline = false
    public private(set) var announcement: String?
    public private(set) var checkedRaceIDs: Set<String> = []
    public var error: FiscalError?
    @ObservationIgnored private let service: (any LiveResultsService)?
    @ObservationIgnored private let interval: Duration

    public init(service: (any LiveResultsService)?, interval: Duration = .seconds(15)) {
        self.service = service
        self.interval = interval
    }

    public var isConfigured: Bool { service != nil }

    public var president: Race? { races.first { $0.office == .president } }

    public var governors: [Race] { races.filter { $0.office == .governor } }

    public var region: RaceRegion?
    public var status: RaceStatusFilter = .all

    public var featured: Race? { president ?? races.first }

    public var others: [Race] { races.filter { $0.id != featured?.id } }

    public var groups: [RaceGroup] {
        let shown = others.filter { race in
            status.includes(race) && (region == nil || RaceRegion.of(uf: race.uf) == region)
        }
        let regions: [RaceRegion?] = RaceRegion.allCases.map(Optional.some) + [nil]
        return regions.compactMap { region in
            let races = shown.filter { RaceRegion.of(uf: $0.uf) == region }
            return races.isEmpty ? nil : RaceGroup(region: region, races: races)
        }
    }

    public var regionChoices: [RaceRegion] {
        RaceRegion.allCases.filter { region in
            others.contains { RaceRegion.of(uf: $0.uf) == region }
        }
    }

    public var activeFilterCount: Int { (region == nil ? 0 : 1) + (status == .all ? 0 : 1) }

    public var hasFilter: Bool { activeFilterCount > 0 }

    public var filterSummary: String {
        [region?.title, status == .all ? nil : status.title].compactMap { $0 }.joined(
            separator: ", ")
    }

    public func clearFilters() {
        region = nil
        status = .all
    }

    public var scopeText: String {
        [region?.title ?? String(appLocalized: "All Regions"), status.title].joined(
            separator: " · ")
    }

    public func race(id: String) -> Race? { races.first { $0.id == id } }

    func detailPhase(for id: String) -> RaceDetailPhase {
        if let race = race(id: id) { return .ready(RaceSummary(race: race)) }
        return checkedRaceIDs.contains(id) ? .unavailable : .loading
    }

    public func detailTitle(for id: String) -> String {
        race(id: id).map(title) ?? ""
    }

    public func loadDetail(id: String) async {
        if race(id: id) == nil { await refresh() }
        checkedRaceIDs.insert(id)
    }

    public func groupHeader(_ group: RaceGroup) -> String {
        "\(group.title) · \(group.races.count)"
    }

    public var isWaiting: Bool { hasLoaded && !races.contains(where: \.hasStarted) }

    public func run() async {
        while !Task.isCancelled {
            await refresh()
            try? await Task.sleep(for: interval)
        }
    }

    public func refresh() async {
        guard let service else {
            hasLoaded = true
            return
        }
        do {
            let fresh = try await service.races()
            announcement = Self.announcement(from: races, to: fresh)
            races = fresh
            hasLoaded = true
            isOffline = false
        } catch is CancellationError {} catch let error as URLError where error.code == .cancelled {
        } catch {
            isOffline = true
            hasLoaded = true
        }
    }

    public func title(_ race: Race) -> String { RaceText.title(office: race.office, uf: race.uf) }

    public func sectionsText(_ race: Race) -> String {
        RaceText.sections(counted: race.sections.counted, total: race.sections.total)
    }

    public func sectionsPercentText(_ race: Race) -> String {
        RaceText.percent(race.sections.percent)
    }

    public func percentText(_ candidate: RaceCandidate, in race: Race) -> String {
        race.hasStarted ? RaceText.percent(candidate.percent) : "—"
    }

    public func votesText(_ candidate: RaceCandidate, in race: Race) -> String {
        race.hasStarted ? String(appLocalized: "\(RaceText.votes(candidate.votes)) votes") : "—"
    }

    public func index(of candidate: RaceCandidate, in race: Race) -> Int {
        race.candidates.firstIndex { $0.number == candidate.number } ?? 0
    }

    public func partyText(_ candidate: RaceCandidate) -> String {
        "\(candidate.party) · \(candidate.number)"
    }

    public var notice: (text: String, symbol: String)? {
        if isOffline {
            return (
                String(appLocalized: "No connection. Showing the last numbers received."),
                "wifi.slash"
            )
        }
        if isWaiting {
            return (
                String(
                    appLocalized:
                        "The count starts at 5 PM Brasília time. Numbers come straight from the TSE, with no projections or polls."
                ), "clock"
            )
        }
        return nil
    }

    public func updatedText(_ race: Race) -> String? {
        guard let date = race.generatedAt else { return nil }
        return String(appLocalized: "TSE file from \(RaceText.time(date))")
    }

    public func accessibilityLabel(_ candidate: RaceCandidate, in race: Race) -> String {
        let base = String(
            appLocalized:
                "\(candidate.name), \(candidate.party), number \(candidate.number), \(percentText(candidate, in: race)), \(votesText(candidate, in: race))"
        )
        return candidate.elected ? "\(base), \(String(appLocalized: "Elected"))" : base
    }

    public func statusText(_ race: Race) -> String {
        if race.final { return String(appLocalized: "Final result") }
        if race.hasStarted { return String(appLocalized: "Counting") }
        return String(appLocalized: "Starts at 5 PM Brasília time")
    }

    static func announcement(from old: [Race], to new: [Race]) -> String? {
        let before = Dictionary(old.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let decided = new.filter { race in
            guard let previous = before[race.id] else { return false }
            return race.final && !previous.final
        }
        guard !decided.isEmpty else { return nil }
        return decided.map { race in
            let title = RaceText.title(office: race.office, uf: race.uf)
            guard let elected = race.elected else {
                return String(appLocalized: "\(title): count finished")
            }
            return "\(title): \(RaceText.elected(elected.name))"
        }.joined(separator: ". ")
    }
}
