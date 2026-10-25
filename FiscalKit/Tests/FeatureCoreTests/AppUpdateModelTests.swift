import FeatureCore
import FiscalDomain
import Foundation
import Testing

private actor FakeReleaseSource: AppReleaseSource {
    var release: AppRelease?
    var fails = false
    private(set) var calls: [AppPlatform] = []

    init(_ release: AppRelease?) {
        self.release = release
    }

    func set(_ release: AppRelease?, fails: Bool = false) {
        self.release = release
        self.fails = fails
    }

    func fetch(platform: AppPlatform) async throws -> AppRelease? {
        calls.append(platform)
        if fails { throw URLError(.notConnectedToInternet) }
        return release
    }
}

private final class Clock: @unchecked Sendable {
    var date = Date(timeIntervalSince1970: 1_800_000_000)
}

@MainActor
struct AppUpdateModelTests {
    private let installed = InstalledApp(
        info: ["CFBundleShortVersionString": "1.0", "CFBundleVersion": "66"])
    private let directory = FileManager.default.temporaryDirectory.appending(
        path: UUID().uuidString)
    private let defaults = UserDefaults(suiteName: UUID().uuidString) ?? .standard
    private let clock = Clock()

    private func policy(minimum: String, recommended: String) throws -> AppRelease {
        AppRelease(
            minimumVersion: try #require(AppVersion(minimum)), minimumBuild: 1,
            recommendedVersion: try #require(AppVersion(recommended)), recommendedBuild: 1)
    }

    private func model(_ source: FakeReleaseSource?, enforces: Bool = true) -> AppUpdateModel {
        let clock = clock
        return AppUpdateModel(
            store: AppReleaseStore(directory: directory), source: source, installed: installed,
            platform: .visionos, enforces: enforces, defaults: defaults,
            appStoreURL: URL(string: "https://apps.apple.com/app/id1"), now: { clock.date })
    }

    @Test func blocksAfterReadingARequiredPolicy() async throws {
        let source = FakeReleaseSource(try policy(minimum: "1.1.0", recommended: "1.1.0"))
        let update = model(source)
        #expect(update.state == .current)
        await update.refresh()
        #expect(update.isRequired)
        #expect(await source.calls == [.visionos])
    }

    @Test func offlineKeepsTheCachedBlock() async throws {
        let source = FakeReleaseSource(try policy(minimum: "1.1.0", recommended: "1.1.0"))
        await model(source).refresh()
        await source.set(nil, fails: true)
        let relaunched = model(source)
        #expect(relaunched.isRequired)
        await relaunched.refresh(force: true)
        #expect(relaunched.isRequired)
        #expect(model(nil).isRequired)
    }

    @Test func aMissingRecordClearsThePolicy() async throws {
        let source = FakeReleaseSource(try policy(minimum: "1.1.0", recommended: "1.1.0"))
        let update = model(source)
        await update.refresh()
        await source.set(nil)
        await update.refresh(force: true)
        #expect(update.state == .current)
    }

    @Test func waitsBetweenReads() async throws {
        let source = FakeReleaseSource(try policy(minimum: "1.0.0", recommended: "1.0.0"))
        let update = model(source)
        await update.refresh()
        await update.refresh()
        #expect(await source.calls.count == 1)
        clock.date += AppUpdateModel.interval + 1
        await update.refresh()
        #expect(await source.calls.count == 2)
        await source.set(try policy(minimum: "2.0.0", recommended: "2.0.0"))
        await update.refresh(force: true)
        #expect(update.isRequired)
        clock.date += AppUpdateModel.blockedInterval + 1
        await update.refresh()
        #expect(await source.calls.count == 4)
    }

    @Test func recommendationShowsOncePerRecommendedVersion() async throws {
        let source = FakeReleaseSource(try policy(minimum: "1.0.0", recommended: "1.1.0"))
        let update = model(source)
        await update.refresh()
        #expect(update.state == .recommended)
        update.offerRecommendation()
        #expect(update.isShowingRecommendation)
        update.dismissRecommendation()
        #expect(!update.isShowingRecommendation)
        #expect(update.isRecommendationDue)
        update.offerRecommendation()
        update.recommendationAppeared()
        update.dismissRecommendation()
        #expect(!update.isShowingRecommendation)
        #expect(!update.isRecommendationDue)
        update.offerRecommendation()
        #expect(!update.isShowingRecommendation)
        #expect(!model(source).isRecommendationDue)
        await source.set(try policy(minimum: "1.0.0", recommended: "1.2.0"))
        await update.refresh(force: true)
        #expect(update.isRecommendationDue)
    }

    @Test func developmentBuildsOnlySimulate() async throws {
        let source = FakeReleaseSource(try policy(minimum: "9.0.0", recommended: "9.0.0"))
        let update = model(source, enforces: false)
        await update.refresh()
        #expect(update.state == .current)
        #expect(update.remoteState == .required)
        update.simulate(.required)
        #expect(update.isRequired)
        #expect(update.isSimulating)
        #expect(
            AppReleaseStore(directory: directory).state(for: installed, enforces: false)
                == .required)
        update.simulate(.recommended)
        #expect(update.isRecommendationDue)
        update.recommendationAppeared()
        update.dismissRecommendation()
        #expect(!update.isRecommendationDue)
        #expect(model(source, enforces: false).isRecommendationDue)
        update.simulate(.recommended)
        #expect(update.isRecommendationDue)
        update.simulate(nil)
        #expect(update.state == .current)
        let enforced = model(source)
        enforced.simulate(.current)
        #expect(enforced.isRequired)
        #expect(!enforced.isSimulating)
    }

    @Test func aStaleSimulatedDismissalIsIgnored() {
        defaults.set("simulated", forKey: "fiscal.update.dismissedRecommendation")
        try? AppReleaseStore(directory: directory).write(AppReleaseCache(simulated: .recommended))
        #expect(model(nil, enforces: false).isRecommendationDue)
    }

    @Test func textsCiteTheVersions() async throws {
        let source = FakeReleaseSource(try policy(minimum: "1.1.0", recommended: "1.2.0"))
        let update = model(source)
        await update.refresh()
        #expect(
            update.requiredMessage
                == "Version 1.0 is no longer supported. Update to 1.1.0 or later. You can still export your data."
        )
        #expect(update.recommendedMessage.contains("1.2.0"))
        #expect(!update.recommendedMessage.contains("("))
        let byBuild = AppRelease(
            minimumVersion: try #require(AppVersion("1.0.0")), minimumBuild: 70,
            recommendedVersion: try #require(AppVersion("1.0.0")), recommendedBuild: 80)
        await source.set(byBuild)
        await update.refresh(force: true)
        #expect(update.requiredMessage.contains("1.0 (66)"))
        #expect(update.requiredMessage.contains("1.0.0 (70)"))
        #expect(update.recommendedMessage.contains("1.0.0 (80)"))
        let simulated = model(source, enforces: false)
        simulated.simulate(.required)
        #expect(simulated.requiredMessage.contains("1.0.0 (70)"))
        let empty = AppUpdateModel(
            store: AppReleaseStore(
                directory: FileManager.default.temporaryDirectory.appending(
                    path: UUID().uuidString)),
            installed: installed, enforces: false, defaults: defaults)
        empty.simulate(.required)
        #expect(!empty.requiredMessage.contains("1.0"))
        empty.simulate(.recommended)
        #expect(!empty.recommendedMessage.contains("1.0"))
    }

    @Test func storeLinkUsesTheAppStoreID() {
        #expect(
            AppUpdateModel.storeURL(info: ["FiscalAppStoreID": "1234567890"])?.absoluteString
                == "https://apps.apple.com/app/id1234567890")
        #expect(AppUpdateModel.storeURL(info: ["FiscalAppStoreID": ""]) == nil)
        #expect(AppUpdateModel.storeURL(info: [:]) == nil)
    }

    @Test func theDeveloperArgumentSimulatesOnlyInDevelopmentBuilds() {
        defaults.set("required", forKey: "fiscal.developer.update")
        #expect(model(nil, enforces: false).isRequired)
        #expect(model(nil, enforces: false).isSimulating)
        #expect(!model(nil).isRequired)
    }
}
