import FeatureCore
import FiscalDomain
import Foundation
import Testing

@MainActor
struct HoldGateTests {
    private let directory = FileManager.default.temporaryDirectory.appending(
        path: UUID().uuidString)

    private func update() -> AppUpdateModel {
        AppUpdateModel(
            store: AppReleaseStore(directory: directory), source: nil,
            installed: InstalledApp(
                info: ["CFBundleShortVersionString": "1.0", "CFBundleVersion": "66"]),
            platform: .ios, enforces: false,
            defaults: UserDefaults(suiteName: UUID().uuidString) ?? .standard)
    }

    @Test func aGateStaysHeldUntilTheHoldAttaches() async {
        let gate = HoldGate()
        let hold = UpdateHoldModel(update: update())
        #expect(gate.isHeld)
        await hold.attach([gate.connection])
        #expect(!gate.isHeld)
    }

    @Test func aBlockHoldsEveryConnectionAndTheReleaseOpensThem() async {
        let update = update()
        let races = HoldGate()
        let highlights = HoldGate()
        let hold = UpdateHoldModel(update: update)
        await hold.attach([races.connection, highlights.connection])
        update.simulate(.required)
        await hold.apply()
        #expect(races.isHeld && highlights.isHeld)
        update.simulate(nil)
        await hold.apply()
        #expect(!races.isHeld && !highlights.isHeld)
    }

    @Test func aBlockedLaunchKeepsTheGatesHeld() async {
        let update = update()
        update.simulate(.required)
        let gate = HoldGate()
        let hold = UpdateHoldModel(update: update)
        await hold.attach([gate.connection])
        #expect(gate.isHeld)
    }
}
