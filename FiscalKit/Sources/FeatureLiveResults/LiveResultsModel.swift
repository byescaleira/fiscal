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
    public private(set) var announcement: String?
    public var error: FiscalError?
    @ObservationIgnored private let service: (any LiveResultsService)?
    @ObservationIgnored private let activities: any RaceActivityTracking
    @ObservationIgnored private let environment: PushEnvironment
    @ObservationIgnored private let interval: Duration
    @ObservationIgnored private(set) var pending: [String: String] = [:]
    @ObservationIgnored private var isFlushing = false

    public init(
        service: (any LiveResultsService)?, activities: any RaceActivityTracking,
        environment: PushEnvironment, interval: Duration = .seconds(15)
    ) {
        self.service = service
        self.activities = activities
        self.environment = environment
        self.interval = interval
        activities.onToken = { [weak self] raceID, token in
            self?.pending[token] = raceID
            Task { await self?.flushPending() }
        }
        activities.onFinish = { [weak self] token in
            self?.pending[token] = nil
            Task { [service] in try? await service?.unfollow(pushToken: token) }
            self?.following = activities.activeRaceIDs()
        }
    }

    public var isConfigured: Bool { service != nil }

    public var canFollow: Bool { activities.isAvailable }

    public var president: Race? { races.first { $0.office == .president } }

    public var governors: [Race] { races.filter { $0.office == .governor } }

    public var isWaiting: Bool { hasLoaded && !races.contains(where: \.hasStarted) }

    public func run() async {
        following = activities.activeRaceIDs()
        activities.resume()
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
        await flushPending()
        do {
            let fresh = try await service.races()
            announcement = Self.announcement(from: races, to: fresh)
            races = fresh
            hasLoaded = true
            isOffline = false
            for race in fresh where following.contains(race.id) {
                await activities.update(race)
            }
            following = activities.activeRaceIDs()
        } catch is CancellationError {} catch let error as URLError where error.code == .cancelled {
        } catch {
            isOffline = true
            hasLoaded = true
        }
    }

    func flushPending() async {
        guard let service, !isFlushing else { return }
        isFlushing = true
        defer { isFlushing = false }
        for (token, raceID) in pending {
            do {
                try await service.follow(raceID: raceID, pushToken: token, environment: environment)
                pending[token] = nil
            } catch LiveResultsError.rejected {
                pending[token] = nil
                error = .invalidInput(
                    String(
                        appLocalized:
                            "The server didn't accept this Live Activity. Try following again."))
            } catch {}
        }
    }

    public func isFollowing(_ race: Race) -> Bool { following.contains(race.id) }

    public func canToggle(_ race: Race) -> Bool { !changing.contains(race.id) }

    public func toggle(_ race: Race) async {
        guard canToggle(race) else { return }
        changing.insert(race.id)
        defer { changing.remove(race.id) }
        if following.contains(race.id) {
            let tokens = await activities.end(raceID: race.id)
            following.remove(race.id)
            for token in tokens {
                pending[token] = nil
                try? await service?.unfollow(pushToken: token)
            }
        } else {
            do {
                try activities.start(race)
                following.insert(race.id)
            } catch {
                self.error = .invalidInput(
                    activities.isAvailable
                        ? String(appLocalized: "Couldn't start the Live Activity. Try again.")
                        : String(
                            appLocalized: "Live Activities are turned off for Fiscal in Settings."))
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

    public func percentText(_ candidate: RaceCandidate, in race: Race) -> String {
        race.hasStarted ? RaceText.percent(candidate.percent) : "—"
    }

    public func votesText(_ candidate: RaceCandidate, in race: Race) -> String {
        race.hasStarted ? String(appLocalized: "\(RaceText.votes(candidate.votes)) votes") : "—"
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

    public var activitiesOffText: String? {
        #if os(iOS)
            canFollow
                ? nil
                : String(
                    appLocalized:
                        "Turn on Live Activities for Fiscal in Settings to follow a race on the Lock Screen."
                )
        #else
            nil
        #endif
    }

    public func updatedText(_ race: Race) -> String? {
        guard let date = race.generatedAt else { return nil }
        return String(appLocalized: "TSE file from \(RaceText.time(date))")
    }

    public func showsFollow(_ race: Race) -> Bool {
        canFollow && (!race.final || isFollowing(race))
    }

    public func followLabel(_ race: Race) -> String {
        isFollowing(race)
            ? String(appLocalized: "Stop following \(title(race))")
            : String(appLocalized: "Follow \(title(race)) on the Lock Screen")
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
