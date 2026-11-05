import FeatureLiveResults
import FiscalDomain
import Foundation
import Testing

@testable import AppShell

@MainActor
private final class FakeActivities: HighlightActivityTracking {
    var isAvailable = true
    var active: Set<String> = []
    var pending: PlannedAlert?
    var scheduled: [String] = []
    var endedAll = false
    var endedPending = 0
    var failure: (any Error)?
    var endsPending = true

    func activeHighlightIDs() -> Set<String> { active }
    func pendingHighlight() -> PlannedAlert? { pending }
    func schedule(_ highlight: Highlight, at date: Date) async throws {
        if let failure { throw failure }
        scheduled.append(highlight.id)
        pending = PlannedAlert(highlightId: highlight.id, fireDate: date)
    }
    func endPending() async {
        endedPending += 1
        if endsPending { pending = nil }
    }
    func start(_ highlight: Highlight, now: Date) async throws {}
    func endExpired(now: Date) async {}
    func endAll() async {
        endedAll = true
        pending = nil
    }
}

@MainActor
private final class FakeNotifications: HighlightNotificationScheduling {
    var current: HighlightNotificationStatus = .authorized
    var grants = true
    var asked = 0
    var pendingAlert: PlannedAlert?
    var boards: [HighlightBoard] = []
    var cancelled = 0

    func status() async -> HighlightNotificationStatus { current }
    func requestPermission() async -> Bool {
        asked += 1
        return grants
    }
    func pending() async -> PlannedAlert? { pendingAlert }
    func schedule(_ board: HighlightBoard, at date: Date) async throws {
        boards.append(board)
        pendingAlert = PlannedAlert(highlightId: board.id, fireDate: date)
    }
    func cancel() async {
        cancelled += 1
        pendingAlert = nil
    }
}

private struct Rejected: Error {}

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
    private let notifications = FakeNotifications()
    private let morning = Date.now.addingTimeInterval(3_600).rounded
    private let evening = Date.now.addingTimeInterval(7_200).rounded
    private var ledger: HighlightAlertLedger { HighlightAlertLedger(suiteName: suite) }

    private func highlight(
        _ id: String, weight: Int = 70, daysAgo: Int = 0, subtitle: String = ""
    ) -> Highlight {
        let calendar = HighlightAlertRule.brasilia
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
        return Highlight(
            id: id, kind: .action, title: "Destaque \(id)", subtitle: subtitle, weight: weight,
            repercussion: nil, impact: 60, route: "pessoa", person: nil, proposition: nil,
            date: CalendarDay(date, calendar: calendar), url: nil, signals: .none)
    }

    private func center(_ items: [Highlight]?, allows: Bool = true) async -> HighlightAlertCenter {
        let slots = HighlightAlertSlots(activity: morning, notification: evening)
        let center = HighlightAlertCenter(
            activities: activities, notifications: notifications, ledger: ledger,
            publicData: { items.map { FixedHighlights(items: $0) } }, allows: { allows },
            slots: { _, _ in slots })
        await center.resume()
        return center
    }

    private func forget() {
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
    }

    @Test func openingSchedulesAndDoesNotStartNow() async {
        defer { forget() }
        let center = await center([highlight("h1"), highlight("h2")])
        await center.activate()
        #expect(activities.scheduled == ["h1"])
        #expect(activities.pending?.fireDate == morning)
        #expect(activities.active.isEmpty)
        #expect(ledger.shown.isEmpty)
    }

    @Test func openingSixTimesAsksTheSystemOnce() async {
        defer { forget() }
        let center = await center([highlight("h1")])
        for _ in 0..<6 { await center.activate() }
        #expect(activities.scheduled == ["h1"])
        #expect(activities.endedPending == 0)
    }

    @Test func aHeavierHighlightReplacesThePending() async {
        defer { forget() }
        activities.pending = PlannedAlert(highlightId: "h1", fireDate: morning)
        let center = await center([highlight("h3", weight: 95), highlight("h1", weight: 92)])
        await center.activate()
        #expect(activities.scheduled == ["h3"])
        #expect(activities.endedPending == 1)
    }

    @Test func whatIsOnScreenStaysAndTheNextIsAnother() async {
        defer { forget() }
        activities.active = ["h1"]
        let center = await center([highlight("h1"), highlight("h2")])
        await center.activate()
        #expect(activities.endedAll == false)
        #expect(activities.scheduled == ["h2"])
    }

    @Test(arguments: [false, true])
    func withoutAValidHighlightTheScheduledPlanStays(cdnIsDown: Bool) async {
        defer { forget() }
        let planned = PlannedAlert(highlightId: "h1", fireDate: morning)
        activities.pending = planned
        ledger.save(plan: HighlightAlertPlan(activity: planned))
        let center = await center(cdnIsDown ? nil : [highlight("h5", weight: 69)])
        await center.activate()
        #expect(activities.scheduled.isEmpty)
        #expect(activities.pending == planned)
        #expect(ledger.plan.activity == planned)
    }

    @Test func aPassedAlertIsNotChosenAgain() async {
        defer { forget() }
        ledger.save(
            plan: HighlightAlertPlan(
                activity: PlannedAlert(highlightId: "h1", fireDate: .now.addingTimeInterval(-60))))
        let center = await center([highlight("h1"), highlight("h2")])
        await center.activate()
        #expect(ledger.shown == ["h1"])
        #expect(activities.scheduled == ["h2"])
    }

    @Test func aRefusalIsSilentAndTriesOnTheNextOpening() async {
        defer { forget() }
        activities.failure = Rejected()
        let center = await center([highlight("h1")])
        await center.activate()
        #expect(ledger.shown.isEmpty)
        #expect(ledger.plan.activity == nil)
        activities.failure = nil
        await center.activate()
        #expect(activities.scheduled == ["h1"])
    }

    @Test func turningItOffEndsEverythingAndStopsPlanning() async {
        defer { forget() }
        let center = await center([highlight("h1")])
        await center.activate()
        await center.setEnabled(false)
        #expect(activities.endedAll)
        #expect(ledger.plan.activity == nil)
        activities.scheduled = []
        await center.activate()
        #expect(activities.scheduled.isEmpty)
    }

    @Test func holdingCancelsAndOnlyPlansAfterTheRelease() async {
        defer { forget() }
        ledger.setNotificationEnabled(true)
        let center = await center([highlight("h1"), highlight("h2")])
        await center.activate()
        await center.hold()
        #expect(activities.pending == nil)
        #expect(notifications.pendingAlert == nil)
        #expect(ledger.plan == HighlightAlertPlan())
        activities.scheduled = []
        await center.activate()
        #expect(activities.scheduled.isEmpty)
        await center.resume()
        #expect(activities.scheduled == ["h1"])
    }

    @Test func theRemoteSwitchClearsWhatIsScheduled() async {
        defer { forget() }
        activities.pending = PlannedAlert(highlightId: "h1", fireDate: morning)
        let center = await center([highlight("h1")], allows: false)
        await center.activate()
        #expect(activities.pending == nil)
    }

    @Test func theNotificationTakesTheSecondHighlight() async {
        defer { forget() }
        ledger.setNotificationEnabled(true)
        let center = await center([highlight("h1", weight: 92), highlight("h2", weight: 90)])
        await center.activate()
        #expect(activities.scheduled == ["h1"])
        #expect(notifications.boards.map(\.id) == ["h2"])
        #expect(notifications.pendingAlert?.fireDate == evening)
    }

    @Test func aSingleHighlightSendsNoNotification() async {
        defer { forget() }
        ledger.setNotificationEnabled(true)
        let center = await center([highlight("h1")])
        await center.activate()
        #expect(notifications.boards.isEmpty)
    }

    @Test func withActivitiesOffTheNotificationTakesTheFirst() async {
        defer { forget() }
        ledger.setNotificationEnabled(true)
        activities.isAvailable = false
        let center = await center([highlight("h1"), highlight("h2")])
        await center.activate()
        #expect(activities.scheduled.isEmpty)
        #expect(notifications.boards.map(\.id) == ["h1"])
    }

    @Test func theSameNotificationIsNotScheduledTwice() async {
        defer { forget() }
        ledger.setNotificationEnabled(true)
        let center = await center([highlight("h1"), highlight("h2")])
        await center.activate()
        await center.activate()
        #expect(notifications.boards.map(\.id) == ["h2"])
    }

    @Test func theNotificationNeverAsksPermissionByItself() async {
        defer { forget() }
        let center = await center([highlight("h1"), highlight("h2")])
        await center.activate()
        #expect(notifications.asked == 0)
        #expect(notifications.boards.isEmpty)
        #expect(!ledger.isNotificationEnabled)
    }

    @Test func turningTheNotificationOnAsksAndPlans() async {
        defer { forget() }
        let center = await center([highlight("h1"), highlight("h2")])
        #expect(await center.setNotificationEnabled(true))
        #expect(notifications.asked == 1)
        #expect(ledger.isNotificationEnabled)
        #expect(notifications.boards.map(\.id) == ["h2"])
    }

    @Test func aRefusedPermissionLeavesItOff() async {
        defer { forget() }
        notifications.grants = false
        notifications.current = .denied
        let center = await center([highlight("h1"), highlight("h2")])
        #expect(await center.setNotificationEnabled(true) == false)
        #expect(!ledger.isNotificationEnabled)
        #expect(notifications.boards.isEmpty)
    }

    @Test func turningTheNotificationOffRemovesIt() async {
        defer { forget() }
        ledger.setNotificationEnabled(true)
        let center = await center([highlight("h1"), highlight("h2")])
        await center.activate()
        _ = await center.setNotificationEnabled(false)
        #expect(notifications.pendingAlert == nil)
        #expect(ledger.plan.notification == nil)
    }

    @Test func aPermissionRemovedInTheSystemSchedulesNothing() async {
        defer { forget() }
        ledger.setNotificationEnabled(true)
        notifications.current = .denied
        let center = await center([highlight("h1"), highlight("h2")])
        await center.activate()
        #expect(notifications.boards.isEmpty)
    }

    @Test func theBackgroundOnlyTouchesTheNotification() async {
        defer { forget() }
        ledger.setNotificationEnabled(true)
        let planned = PlannedAlert(highlightId: "h1", fireDate: morning)
        activities.pending = planned
        ledger.save(plan: HighlightAlertPlan(activity: planned))
        let center = await center([
            highlight("h1", weight: 92), highlight("h9", weight: 99), highlight("h2", weight: 90),
        ])
        await center.refreshInBackground()
        #expect(activities.scheduled.isEmpty)
        #expect(activities.endedPending == 0)
        #expect(notifications.boards.map(\.id) == ["h9"])
    }

    @Test func aPendingThatCannotEndIsKeptAndNothingElseIsAsked() async {
        defer { forget() }
        let stuck = PlannedAlert(highlightId: "h1", fireDate: morning)
        activities.pending = stuck
        activities.endsPending = false
        let center = await center([highlight("h3", weight: 95)])
        await center.activate()
        #expect(activities.scheduled.isEmpty)
        #expect(ledger.plan.activity == stuck)
    }

    @Test func thePortraitIsPreparedBeforeScheduling() async {
        defer { forget() }
        var prepared: [String] = []
        let slots = HighlightAlertSlots(activity: morning, notification: evening)
        let center = HighlightAlertCenter(
            activities: activities, notifications: notifications, ledger: ledger,
            publicData: { FixedHighlights(items: [highlight("h1")]) }, allows: { true },
            slots: { _, _ in slots }, prepare: { prepared.append($0.id) })
        await center.resume()
        await center.activate()
        await center.activate()
        #expect(prepared == ["h1"])
    }

    @Test func theLegacyTokenIsErasedOnOpening() async {
        defer { forget() }
        UserDefaults(suiteName: suite)?.set("token-1", forKey: "fiscal.highlightAlerts.token")
        let center = await center([])
        await center.activate()
        #expect(
            UserDefaults(suiteName: suite)?.string(forKey: "fiscal.highlightAlerts.token") == nil)
    }

    @Test func theBodyCarriesTheSubtitleAndTheUncertainty() {
        let board = HighlightBoard(highlight("h1", subtitle: "Subtítulo"))
        let uncertainty = board.uncertaintyShort ?? ""
        #expect(!uncertainty.isEmpty)
        #expect(board.notificationBody == "Subtítulo \(uncertainty)")
    }
}

extension Date {
    fileprivate var rounded: Date {
        Date(timeIntervalSince1970: timeIntervalSince1970.rounded())
    }
}
