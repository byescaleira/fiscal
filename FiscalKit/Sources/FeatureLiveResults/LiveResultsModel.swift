import FeatureCore
import FiscalDomain
import Foundation
import Observation

@MainActor @Observable
public final class LiveResultsModel {
    public private(set) var races: [Race] = []
    public private(set) var hasLoaded = false
    public private(set) var isOffline = false
    public private(set) var following: Set<String> = []
    public private(set) var changing: Set<String> = []
    public var error: FiscalError?
    @ObservationIgnored private let service: (any LiveResultsService)?
    @ObservationIgnored private let activities: any RaceActivityTracking
    @ObservationIgnored private let environment: PushEnvironment
    @ObservationIgnored private let interval: Duration

    public init(
        service: (any LiveResultsService)?, activities: any RaceActivityTracking,
        environment: PushEnvironment, interval: Duration = .seconds(15)
    ) {
        self.service = service
        self.activities = activities
        self.environment = environment
        self.interval = interval
    }

    public var isConfigured: Bool { service != nil }

    public var canFollow: Bool { activities.isAvailable }

    public var president: Race? { races.first { $0.office == .president } }

    public var governors: [Race] { races.filter { $0.office == .governor } }

    public var isWaiting: Bool { hasLoaded && !races.contains(where: \.hasStarted) }

    public func run() async {
        following = activities.activeRaceIDs()
        activities.resume { [weak self] raceID, token in
            self?.register(raceID: raceID, token: token)
        }
        while !Task.isCancelled {
            await refresh()
            try? await Task.sleep(for: interval)
        }
    }

    public func refresh() async {
        guard let service else { return }
        do {
            let fresh = try await service.races()
            races = fresh
            hasLoaded = true
            isOffline = false
            for race in fresh where following.contains(race.id) {
                await activities.update(race)
            }
            following = activities.activeRaceIDs()
        } catch is CancellationError {} catch {
            isOffline = true
            hasLoaded = true
        }
    }

    public func isFollowing(_ race: Race) -> Bool { following.contains(race.id) }

    public func toggle(_ race: Race) async {
        guard !changing.contains(race.id) else { return }
        changing.insert(race.id)
        defer { changing.remove(race.id) }
        if following.contains(race.id) {
            let tokens = await activities.end(raceID: race.id)
            following.remove(race.id)
            for token in tokens {
                try? await service?.unfollow(pushToken: token)
            }
        } else {
            do {
                try activities.start(race) { [weak self] token in
                    self?.register(raceID: race.id, token: token)
                }
                following.insert(race.id)
            } catch {
                self.error = .invalidInput(
                    String(appLocalized: "Live Activities are turned off for Fiscal in Settings."))
            }
        }
    }

    public func title(_ race: Race) -> String { RaceText.title(office: race.office, uf: race.uf) }

    public func sectionsText(_ race: Race) -> String {
        RaceText.sections(counted: race.sections.counted, total: race.sections.total)
    }

    public func sectionsPercentText(_ race: Race) -> String {
        RaceText.percent(race.sections.percent)
    }

    public func percentText(_ candidate: RaceCandidate) -> String {
        RaceText.percent(candidate.percent)
    }

    public func votesText(_ candidate: RaceCandidate) -> String {
        String(appLocalized: "\(RaceText.votes(candidate.votes)) votes")
    }

    public func updatedText(_ race: Race) -> String {
        guard let date = race.generatedAt else { return "" }
        return String(appLocalized: "TSE file from \(RaceText.time(date))")
    }

    public func statusText(_ race: Race) -> String {
        if let elected = race.elected { return RaceText.elected(elected.name) }
        if race.final { return String(appLocalized: "Count finished") }
        if race.hasStarted { return String(appLocalized: "Counting") }
        return String(appLocalized: "Starts at 5 PM Brasília time")
    }

    private func register(raceID: String, token: String) {
        guard let service else { return }
        let environment = environment
        Task {
            for attempt in 0..<3 {
                do {
                    try await service.follow(
                        raceID: raceID, pushToken: token, environment: environment)
                    return
                } catch {
                    try? await Task.sleep(for: .seconds(2 << attempt))
                }
            }
        }
    }
}
