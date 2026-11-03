import FeatureLiveResults
import FiscalDomain
import Foundation
import Testing

@testable import AppShell

@MainActor
private final class FakeActivities: HighlightActivityTracking {
    var isAvailable = true
    var onStartToken: (@MainActor (_ token: String) -> Void)?
    var onShown: (@MainActor (_ highlightID: String) -> Void)?
    var active: Set<String> = []
    var started: [String] = []
    var endedAll = false
    var failsToStart = false

    func activeHighlightIDs() -> Set<String> { active }
    func observe() {}
    func start(_ highlight: Highlight, now: Date) async throws {
        if failsToStart { throw PublicDataError.unavailable }
        started.append(highlight.id)
    }
    func endExpired(now: Date) async {}
    func endAll() async { endedAll = true }
}

private final class FakeAlertService: HighlightAlertService {
    let registered: AsyncStream<String>
    private let continuation: AsyncStream<String>.Continuation

    init() {
        (registered, continuation) = AsyncStream.makeStream()
    }

    func registerHighlights(pushToken: String, environment: PushEnvironment) async throws {
        continuation.yield(pushToken)
    }
    func unregisterHighlights(pushToken: String) async throws {}
}

private struct FixedHighlights: PublicDataService {
    let items: [Highlight]

    func meta() async throws -> PublicMeta { throw PublicDataError.notFound }
    func people() async throws -> [PersonCard] { [] }
    func places() async throws -> [Place] { [] }
    func representatives(uf: String) async throws -> PlaceRepresentatives {
        throw PublicDataError.notFound
    }
    func profile(slug: String) async throws -> Profile { throw PublicDataError.notFound }
    func votes(slug: String, year: Int) async throws -> PublicList<PersonVote> {
        throw PublicDataError.notFound
    }
    func proposals(slug: String, year: Int) async throws -> PublicList<Proposal> {
        throw PublicDataError.notFound
    }
    func speeches(slug: String, year: Int) async throws -> PublicList<Speech> {
        throw PublicDataError.notFound
    }
    func expenses(slug: String, year: Int) async throws -> ExpenseList {
        throw PublicDataError.notFound
    }
    func checks(slug: String) async throws -> FactCheckList? { nil }
    func recentVotes() async throws -> [VoteSummary] { [] }
    func vote(id: String) async throws -> VoteDetail { throw PublicDataError.notFound }
    func agenda() async throws -> Agenda { throw PublicDataError.notFound }
    func money() async throws -> MoneyOverview { throw PublicDataError.notFound }
    func today() async throws -> TodayDigest { throw PublicDataError.notFound }
    func highlights() async throws -> HighlightList? {
        HighlightList(generatedAt: nil, items: items, method: nil, sources: [])
    }
}

@MainActor
struct HighlightAlertCenterTests {
    private let suite = "test.highlight-center.\(UUID().uuidString)"
    private let activities = FakeActivities()
    private let service = FakeAlertService()
    private var ledger: HighlightAlertLedger { HighlightAlertLedger(suiteName: suite) }

    private func highlight(_ id: String, weight: Int = 70, daysAgo: Int = 0) -> Highlight {
        let calendar = HighlightAlertRule.brasilia
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
        return Highlight(
            id: id, kind: .action, title: "Destaque \(id)", subtitle: "", weight: weight,
            repercussion: nil, impact: 60, route: "pessoa", person: nil, proposition: nil,
            date: CalendarDay(date, calendar: calendar), url: nil, signals: .none)
    }

    private func center(_ items: [Highlight], allows: Bool = true) -> HighlightAlertCenter {
        let service = service
        return HighlightAlertCenter(
            activities: activities, ledger: ledger, service: { service },
            publicData: { FixedHighlights(items: items) }, allows: { allows })
    }

    private func forget() {
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
    }

    @Test func aHighlightThatPassesStartsAndIsRemembered() async {
        defer { forget() }
        let center = center([highlight("a")])
        await center.resume()
        await center.consider()
        #expect(activities.started == ["a"])
        #expect(ledger.shown == ["a"])
    }

    @Test func aHighlightBelowTheMinimumWeightDoesNotStart() async {
        defer { forget() }
        let center = center([highlight("a", weight: 69)])
        await center.resume()
        await center.consider()
        #expect(activities.started.isEmpty)
        #expect(ledger.shown.isEmpty)
    }

    @Test func aHighlightOutsideTheWindowDoesNotStart() async {
        defer { forget() }
        let center = center([highlight("a", daysAgo: 3)])
        await center.resume()
        await center.consider()
        #expect(activities.started.isEmpty)
    }

    @Test func whatWasAlreadyAlertedDoesNotStartAgain() async {
        defer { forget() }
        ledger.record("a")
        let center = center([highlight("a"), highlight("b")])
        await center.resume()
        await center.consider()
        await center.consider()
        #expect(activities.started == ["b"])
    }

    @Test func whatIsOnTheLockScreenNowDoesNotStartAgain() async {
        defer { forget() }
        activities.active = ["a"]
        let center = center([highlight("a")])
        await center.resume()
        await center.consider()
        #expect(activities.started.isEmpty)
    }

    @Test func aFailedStartIsNotRememberedSoItCanTryAgain() async {
        defer { forget() }
        activities.failsToStart = true
        let center = center([highlight("a")])
        await center.resume()
        await center.consider()
        #expect(ledger.shown.isEmpty)
        activities.failsToStart = false
        await center.consider()
        #expect(activities.started == ["a"])
    }

    @Test func nothingStartsWhileHeldTurnedOffOrDisallowed() async {
        defer { forget() }
        let held = center([highlight("a")])
        await held.consider()
        #expect(activities.started.isEmpty)

        let disallowed = center([highlight("a")], allows: false)
        await disallowed.resume()
        await disallowed.consider()
        #expect(activities.started.isEmpty)

        ledger.setEnabled(false)
        let off = center([highlight("a")])
        await off.resume()
        await off.consider()
        #expect(activities.started.isEmpty)
    }

    @Test func nothingStartsWhenTheSystemHasLiveActivitiesOff() async {
        defer { forget() }
        activities.isAvailable = false
        let center = center([highlight("a")])
        await center.resume()
        await center.consider()
        #expect(activities.started.isEmpty)
    }

    @Test func turningItOffEndsEverythingOnTheLockScreen() async {
        defer { forget() }
        let center = center([highlight("a")])
        await center.resume()
        await center.setEnabled(false)
        #expect(activities.endedAll)
        #expect(!ledger.isEnabled)
    }

    @Test func aNewStartTokenIsRegisteredAndSaved() async {
        defer { forget() }
        let center = center([])
        await center.resume()
        await center.activate()
        activities.onStartToken?("token-1")
        var iterator = service.registered.makeAsyncIterator()
        #expect(await iterator.next() == "token-1")
    }
}
