import FeatureCore
import FiscalDomain
import Foundation
import Testing

private actor PolicySource: AppReleaseSource {
    var release: AppRelease?
    var fails = false

    func set(_ release: AppRelease?, fails: Bool = false) {
        self.release = release
        self.fails = fails
    }

    func fetch(platform: AppPlatform) async throws -> AppRelease? {
        if fails { throw URLError(.notConnectedToInternet) }
        return release
    }
}

@MainActor
private final class Recorder {
    var events: [String] = []

    func connection(_ name: String) -> UpdateHoldModel.Connection {
        UpdateHoldModel.Connection {
            self.events.append("start \(name)")
        } stop: {
            self.events.append("stop \(name)")
        }
    }
}

@MainActor
struct UpdateHoldModelTests {
    private let source = PolicySource()
    private let recorder = Recorder()
    private let directory = FileManager.default.temporaryDirectory.appending(
        path: UUID().uuidString)

    private func required() throws -> AppRelease {
        let version = try #require(AppVersion("2.0.0"))
        return AppRelease(
            minimumVersion: version, minimumBuild: 1, recommendedVersion: version,
            recommendedBuild: 1)
    }

    private func model(enforces: Bool = true) -> AppUpdateModel {
        AppUpdateModel(
            store: AppReleaseStore(directory: directory), source: source,
            installed: InstalledApp(
                info: ["CFBundleShortVersionString": "1.0", "CFBundleVersion": "66"]),
            platform: .ios, enforces: enforces,
            defaults: UserDefaults(suiteName: UUID().uuidString) ?? .standard)
    }

    private func hold(_ update: AppUpdateModel) async -> UpdateHoldModel {
        let hold = UpdateHoldModel(update: update)
        await hold.attach([recorder.connection("sharing"), recorder.connection("web")])
        return hold
    }

    @Test func startsEverythingWhenTheLaunchIsFree() async {
        let hold = await hold(model())
        #expect(!hold.isHolding)
        #expect(recorder.events == ["start sharing", "start web"])
    }

    @Test func aBlockedLaunchStartsNothing() async throws {
        await source.set(try required())
        let update = model()
        await update.refresh(force: true)
        let hold = await hold(update)
        #expect(hold.isHolding)
        #expect(recorder.events.isEmpty)
    }

    @Test func aBlockWhileOpenStopsAndTheReleaseStartsAgain() async throws {
        let update = model()
        let hold = await hold(update)
        await source.set(try required())
        await update.refresh(force: true)
        await hold.apply()
        #expect(hold.isHolding)
        await source.set(nil)
        await update.refresh(force: true)
        await hold.apply()
        #expect(!hold.isHolding)
        #expect(
            recorder.events == [
                "start sharing", "start web", "stop sharing", "stop web", "start sharing",
                "start web",
            ])
    }

    @Test func aBlockedLaunchStartsOnRelease() async throws {
        await source.set(try required())
        let update = model()
        await update.refresh(force: true)
        let hold = await hold(update)
        await source.set(nil)
        await update.refresh(force: true)
        await hold.apply()
        #expect(recorder.events == ["start sharing", "start web"])
    }

    @Test func offlineKeepsHolding() async throws {
        let update = model()
        let hold = await hold(update)
        await source.set(try required())
        await update.refresh(force: true)
        await hold.apply()
        await source.set(nil, fails: true)
        await update.refresh(force: true)
        await hold.apply()
        await hold.apply()
        #expect(hold.isHolding)
        #expect(recorder.events == ["start sharing", "start web", "stop sharing", "stop web"])
    }

    @Test func applyingBeforeAttachingWaitsForTheConnections() async {
        let update = model(enforces: false)
        let hold = UpdateHoldModel(update: update)
        update.simulate(.required)
        await hold.apply()
        update.simulate(nil)
        await hold.apply()
        #expect(recorder.events.isEmpty)
        await hold.attach([recorder.connection("mcp")])
        #expect(recorder.events == ["start mcp"])
    }

    @Test func simulatingTheBlockStopsAndResumes() async {
        let update = model(enforces: false)
        let hold = await hold(update)
        update.simulate(.required)
        await hold.apply()
        update.simulate(nil)
        await hold.apply()
        #expect(
            recorder.events == [
                "start sharing", "start web", "stop sharing", "stop web", "start sharing",
                "start web",
            ])
    }

    @Test func aReleaseDuringTheStopEndsStarted() async {
        let update = model(enforces: false)
        let hold = UpdateHoldModel(update: update)
        let recorder = recorder
        let releasing = UpdateHoldModel.Connection {
            recorder.events.append("start web")
        } stop: {
            recorder.events.append("stop web")
            update.simulate(nil)
            await hold.apply()
        }
        await hold.attach([releasing])
        update.simulate(.required)
        await hold.apply()
        #expect(!hold.isHolding)
        #expect(recorder.events == ["start web", "stop web", "start web"])
    }
}
