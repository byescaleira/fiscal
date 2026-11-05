import FeatureCore
import FeatureLiveResults
import FeatureSettings
import FiscalData
import FiscalDomain
import Foundation

@MainActor
final class HighlightAlertCenter {
    static let shared = HighlightAlertCenter()

    private let activities: any HighlightActivityTracking
    private let notifications: any HighlightNotificationScheduling
    private let ledger: HighlightAlertLedger
    private let publicData: @MainActor () -> (any PublicDataService)?
    private let allows: @MainActor () -> Bool
    private let slots:
        @MainActor (_ schedule: HighlightAlertSchedule, _ offset: Int, _ now: Date) ->
            HighlightAlertSlots
    private let prepare: @MainActor (Highlight) -> Void
    private var isHeld = true
    private var wantsActivation = false
    private var isPlanning = false
    private var plansAgain = false
    private var didForceShowcase = false

    init(
        activities: any HighlightActivityTracking = HighlightActivities(),
        notifications: any HighlightNotificationScheduling = HighlightNotifications(),
        ledger: HighlightAlertLedger = HighlightAlertLedger(),
        publicData: @escaping @MainActor () -> (any PublicDataService)? = {
            FiscalServices.shared.publicData()
        },
        allows: @escaping @MainActor () -> Bool = {
            FiscalServices.shared.isOn(.highlightAlerts)
        },
        slots:
            @escaping @MainActor (_ schedule: HighlightAlertSchedule, _ offset: Int, _ now: Date)
            -> HighlightAlertSlots = {
                HighlightAlertCenter.defaultSlots(schedule: $0, offset: $1, now: $2)
            },
        prepare: @escaping @MainActor (Highlight) -> Void = {
            HighlightAlertCenter.shelvePortrait(of: $0)
        }
    ) {
        self.activities = activities
        self.notifications = notifications
        self.ledger = ledger
        self.publicData = publicData
        self.allows = allows
        self.slots = slots
        self.prepare = prepare
    }

    func activate() async {
        wantsActivation = true
        guard !isHeld else { return }
        ledger.clearLegacy()
        let now = Date.now
        if ledger.isEnabled || ledger.isNotificationEnabled {
            ledger.recordOpening(now)
        } else {
            ledger.clearHabit()
        }
        await activities.endExpired(now: now)
        for _ in ledger.settle(now: now) { FiscalEvents.alertReceived.log() }
        #if DEBUG
            if await forceShowcase() { return }
        #endif
        await applyPlan(isForeground: true)
    }

    func refreshInBackground() async {
        guard !isHeld else { return }
        await applyPlan(isForeground: false)
    }

    func resume() async {
        isHeld = false
        if wantsActivation { await activate() }
    }

    func hold() async {
        isHeld = true
        await clearScheduled()
    }

    func setEnabled(_ isOn: Bool) async {
        ledger.setEnabled(isOn)
        guard isOn else {
            await activities.endAll()
            var plan = ledger.plan
            plan.activity = nil
            ledger.save(plan: plan)
            return
        }
        guard !isHeld else { return }
        await applyPlan(isForeground: true)
    }

    func setNotificationEnabled(_ isOn: Bool) async -> Bool {
        guard isOn else {
            ledger.setNotificationEnabled(false)
            await cancelNotification()
            return true
        }
        guard await notifications.requestPermission() else {
            ledger.setNotificationEnabled(false)
            return false
        }
        ledger.setNotificationEnabled(true)
        if !isHeld { await applyPlan(isForeground: true) }
        return true
    }

    private func applyPlan(isForeground: Bool) async {
        guard !isPlanning else {
            plansAgain = true
            return
        }
        isPlanning = true
        await planOnce(isForeground: isForeground)
        isPlanning = false
        if plansAgain {
            plansAgain = false
            await applyPlan(isForeground: isForeground)
        }
    }

    private func planOnce(isForeground: Bool) async {
        guard allows() else {
            await clearScheduled()
            return
        }
        let wantsNotification =
            ledger.isNotificationEnabled ? await notifications.status() == .authorized : false
        if !wantsNotification { await cancelNotification() }
        guard let data = publicData(), let list = try? await data.highlights() else { return }
        let now = Date.now
        var excluding = activities.activeHighlightIDs()
        if !isForeground, let pending = ledger.plan.activity {
            excluding.insert(pending.highlightId)
        }
        let next = HighlightAlertPlanner.plan(
            items: list.items, shown: ledger.shown, excluding: excluding,
            rule: list.method?.alertRule ?? .standard,
            wantsActivity: isForeground && ledger.isEnabled && activities.isAvailable,
            wantsNotification: wantsNotification,
            slots: slots(ledger.habit.schedule(now: now), ledger.deviceOffset(), now))
        var plan = ledger.plan
        if let planned = next.activity,
            let highlight = list.items.first(where: { $0.id == planned.highlightId })
        {
            plan.activity = await place(highlight, planned)
        }
        if let planned = next.notification,
            let highlight = list.items.first(where: { $0.id == planned.highlightId })
        {
            plan.notification = await place(notification: highlight, planned)
        }
        ledger.save(plan: plan)
    }

    private func place(_ highlight: Highlight, _ planned: PlannedAlert) async -> PlannedAlert? {
        let current = activities.pendingHighlight()
        if planned.isSame(as: current) { return current }
        if current != nil {
            await activities.endPending()
            if let left = activities.pendingHighlight() { return left }
        }
        prepare(highlight)
        do {
            try await activities.schedule(highlight, at: planned.fireDate)
            return planned
        } catch {
            return nil
        }
    }

    private func place(notification highlight: Highlight, _ planned: PlannedAlert) async
        -> PlannedAlert?
    {
        let current = await notifications.pending()
        if planned.isSame(as: current) { return current }
        do {
            try await notifications.schedule(highlight, at: planned.fireDate)
            return planned
        } catch {
            return current
        }
    }

    private func cancelNotification() async {
        await notifications.cancel()
        var plan = ledger.plan
        plan.notification = nil
        ledger.save(plan: plan)
    }

    private func clearScheduled() async {
        await activities.endPending()
        await notifications.cancel()
        ledger.save(plan: HighlightAlertPlan())
    }

    func notificationsAreDenied() async -> Bool {
        await notifications.status() == .denied
    }

    private static let portraits = PortraitStore()

    private static func shelvePortrait(of highlight: Highlight) {
        PortraitStore.pruneShelf()
        guard let person = highlight.person else { return }
        portraits.shelve(slug: person.slug, party: person.party)
    }

    private static func defaultSlots(schedule: HighlightAlertSchedule, offset: Int, now: Date)
        -> HighlightAlertSlots
    {
        #if DEBUG
            if let test = testSlots { return test }
        #endif
        return schedule.slots(offset: offset, now: now)
    }

    #if DEBUG
        static let showcaseKey = "FiscalHighlightAlert"
        private static let testSlotsKey = "FiscalAlertTestSeconds"

        private static let testSlots: HighlightAlertSlots? = {
            let values = (UserDefaults.standard.string(forKey: testSlotsKey) ?? "")
                .split(separator: ",").compactMap { Double($0) }
            guard values.count == 2 else { return nil }
            let now = Date.now.timeIntervalSince1970.rounded()
            return HighlightAlertSlots(
                activity: Date(timeIntervalSince1970: now + values[0]),
                notification: Date(timeIntervalSince1970: now + values[1]))
        }()

        private func forceShowcase() async -> Bool {
            guard UserDefaults.standard.bool(forKey: Self.showcaseKey) else { return false }
            guard !didForceShowcase else { return true }
            didForceShowcase = true
            let source: any PublicDataService =
                publicData() ?? ShowcasePublicData(scenario: .normal)
            guard let lead = try? await source.highlights()?.items.first else { return true }
            try? await activities.start(lead, now: .now)
            return true
        }
    #endif
}

extension SettingsModel {
    public static func fiscal() -> SettingsModel {
        SettingsModel(
            highlightAlertsChanged: { isOn in
                Task { await HighlightAlertCenter.shared.setEnabled(isOn) }
            },
            highlightNotificationChanged: { isOn in
                await HighlightAlertCenter.shared.setNotificationEnabled(isOn)
            },
            notificationsAreDenied: {
                await HighlightAlertCenter.shared.notificationsAreDenied()
            })
    }
}
