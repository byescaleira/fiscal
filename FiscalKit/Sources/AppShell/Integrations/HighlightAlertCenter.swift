import FeatureLiveResults
import FeatureSettings
import FiscalData
import FiscalDomain
import Foundation

@MainActor
final class HighlightAlertCenter {
    static let shared = HighlightAlertCenter()

    private let activities: any HighlightActivityTracking
    private let ledger: HighlightAlertLedger
    private let environment: PushEnvironment
    private let service: @MainActor () -> (any HighlightAlertService)?
    private let publicData: @MainActor () -> (any PublicDataService)?
    private var isObserving = false
    private var latestToken: String?
    private var didForceShowcase = false

    init(
        activities: any HighlightActivityTracking = HighlightActivities(),
        ledger: HighlightAlertLedger = HighlightAlertLedger(),
        service: @escaping @MainActor () -> (any HighlightAlertService)? = {
            FiscalServices.shared.highlightAlertService()
        },
        publicData: @escaping @MainActor () -> (any PublicDataService)? = {
            FiscalServices.shared.publicData()
        }
    ) {
        self.activities = activities
        self.ledger = ledger
        self.service = service
        self.publicData = publicData
        #if DEBUG
            environment = .development
        #else
            environment = .production
        #endif
    }

    func activate() async {
        SettingsModel.onHighlightAlertsChange = { isOn in
            Task { await HighlightAlertCenter.shared.setEnabled(isOn) }
        }
        if !isObserving {
            isObserving = true
            activities.onStartToken = { [weak self] token in self?.received(token) }
            activities.onShown = { [weak self] id in self?.ledger.record(id) }
            activities.observe()
        }
        await activities.endExpired(now: .now)
        guard ledger.isEnabled else {
            await forget()
            return
        }
        #if DEBUG
            if await forceShowcase() { return }
        #endif
        await consider()
    }

    func consider() async {
        guard ledger.isEnabled, activities.isAvailable, let data = publicData(),
            let list = try? await data.highlights()
        else { return }
        let now = Date.now
        let rule = list.method?.alertRule ?? .standard
        let shown = ledger.shown.union(activities.activeHighlightIDs())
        guard let pick = rule.pick(from: list.items, shown: shown, now: now) else { return }
        do {
            try await activities.start(pick, now: now)
            ledger.record(pick.id)
        } catch {}
    }

    func setEnabled(_ isOn: Bool) async {
        ledger.setEnabled(isOn)
        guard isOn else {
            await activities.endAll()
            await forget()
            return
        }
        if let latestToken { register(latestToken) }
        await consider()
    }

    private func received(_ token: String) {
        latestToken = token
        guard ledger.isEnabled else { return }
        register(token)
    }

    private func register(_ token: String) {
        let previous = ledger.registeredToken
        let environment = environment
        guard let service = service() else { return }
        Task { [ledger] in
            do {
                if let previous, previous != token {
                    try? await service.unregisterHighlights(pushToken: previous)
                }
                try await service.registerHighlights(pushToken: token, environment: environment)
                ledger.save(token: token)
            } catch {}
        }
    }

    private func forget() async {
        guard let token = ledger.registeredToken, let service = service() else { return }
        do {
            try await service.unregisterHighlights(pushToken: token)
            ledger.save(token: nil)
        } catch {}
    }

    #if DEBUG
        static let showcaseKey = "FiscalHighlightAlert"

        private func forceShowcase() async -> Bool {
            guard UserDefaults.standard.bool(forKey: Self.showcaseKey) else { return false }
            guard !didForceShowcase else { return true }
            didForceShowcase = true
            let showcase = ShowcasePublicData(scenario: .normal)
            guard let lead = try? await showcase.highlights()?.items.first else { return true }
            try? await activities.start(lead, now: .now)
            return true
        }
    #endif
}
