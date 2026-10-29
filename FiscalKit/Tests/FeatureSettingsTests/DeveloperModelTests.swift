import FeatureCore
import FiscalData
import FiscalDomain
import Foundation
import Testing

@testable import FeatureSettings

private actor FakeReleaseSource: AppReleaseSource {
    let release: AppRelease?

    init(_ release: AppRelease?) {
        self.release = release
    }

    func fetch(platform: AppPlatform) async throws -> AppRelease? { release }
}

private actor FakeFlagSource: RemoteFlagSource {
    private(set) var calls = 0

    func fetch() async throws -> [String: RemoteFlag] {
        calls += 1
        return [:]
    }
}

@MainActor
struct DeveloperModelTests {
    private let defaults = UserDefaults(suiteName: "DeveloperModelTests.\(UUID().uuidString)")
    private let directory = FileManager.default.temporaryDirectory.appending(
        path: UUID().uuidString)
    private let info = AppInfo(info: [
        "CFBundleShortVersionString": "1.2", "CFBundleVersion": "7",
        "CFBundleIdentifier": "com.byescaleira.fiscal",
    ])

    private func suite() throws -> UserDefaults { try #require(defaults) }

    private func update(_ source: FakeReleaseSource? = nil, enforces: Bool = false) throws
        -> AppUpdateModel
    {
        AppUpdateModel(
            store: AppReleaseStore(directory: directory), source: source,
            installed: InstalledApp(version: try #require(AppVersion("1.2")), build: 7),
            enforces: enforces, defaults: try suite())
    }

    private func model(
        flags: FeatureFlags? = nil, update: AppUpdateModel? = nil, session: SessionModel? = nil
    ) throws -> DeveloperModel {
        DeveloperModel(
            flags: flags, update: update, session: session, info: info, defaults: try suite())
    }

    @Test func overridesFlagsAndRestoresTheDefaults() throws {
        let flags = FeatureFlags(defaults: try suite())
        let developer = try model(flags: flags)
        #expect(developer.hasFlags)
        #expect(developer.bucket == flags.bucket)
        #expect(!developer.hasOverrides)

        developer.set(.partyIcons, isOn: true)
        developer.set(.guides, isOn: false)
        #expect(developer.isOn(.partyIcons))
        #expect(!developer.isOn(.guides))
        #expect(developer.hasOverrides)

        developer.restoreFlags()
        #expect(!developer.hasOverrides)
        #expect(developer.isOn(.guides) == FeatureFlag.guides.defaultValue)
        #expect(developer.isOn(.partyIcons) == FeatureFlag.partyIcons.defaultValue)
    }

    @Test func simulatesRecommendedAndRequiredUpdates() throws {
        let update = try update()
        let developer = try model(update: update)
        #expect(developer.canSimulateUpdates)
        #expect(developer.simulation == nil)

        developer.simulation = .recommended
        #expect(update.state == .recommended)
        #expect(update.isSimulating)

        developer.simulation = .required
        #expect(update.isRequired)

        developer.simulation = nil
        #expect(update.state == .current)
        #expect(!update.isSimulating)
        #expect(DeveloperModel.simulations == [nil, .recommended, .required])
    }

    @Test func neverSimulatesWhenTheBuildEnforcesThePolicy() throws {
        #expect(try !model(update: update(enforces: true)).canSimulateUpdates)
        #expect(try !model().canSimulateUpdates)
    }

    @Test func checksNowAndShowsTheRemotePolicy() async throws {
        let release = AppRelease(
            minimumVersion: try #require(AppVersion("1.0")), minimumBuild: 1,
            recommendedVersion: try #require(AppVersion("1.3")), recommendedBuild: 1)
        let developer = try model(update: update(FakeReleaseSource(release)))
        #expect(developer.lastCheckText == String(appLocalized: "Never"))
        #expect(developer.installedText == "1.2 (7)")

        await developer.checkNow()
        #expect(developer.lastCheckText != String(appLocalized: "Never"))
        #expect(developer.remoteStateText == DeveloperModel.title(of: .recommended))
        #expect(developer.policyText.contains("1.3 (1)"))
        #expect(!developer.isChecking)
    }

    @Test func deletesOnlyFiscalPreferences() throws {
        let defaults = try suite()
        let id = UUID().uuidString
        let appearance = "fiscal.test.\(id).appearance"
        let other = "other.test.\(id)"
        let before = try model().preferenceCount
        defaults.set("dark", forKey: appearance)
        defaults.set(true, forKey: "fiscal.test.\(id).cloudSync")
        defaults.set("keep", forKey: other)
        let developer = try model()
        #expect(developer.preferenceCount == before + 2)

        developer.confirmDeletePreferences()
        #expect(developer.isConfirmingDelete)
        developer.deletePreferences()
        #expect(!developer.isConfirmingDelete)
        #expect(developer.preferenceCount <= before)
        #expect(defaults.string(forKey: appearance) == nil)
        #expect(defaults.string(forKey: other) == "keep")
    }

    @Test func reloadsTheSessionAndTheRemoteFlags() async throws {
        let source = FakeFlagSource()
        let flags = FeatureFlags(defaults: try suite(), source: source)
        let session = SessionModel(
            repositories: try FiscalDatabase.open(inMemory: true).repositories)
        let developer = try model(flags: flags, session: session)
        #expect(developer.canReload)

        await developer.reloadData()
        #expect(session.generation == 1)
        #expect(await source.calls == 1)
        #expect(!developer.isReloading)
        #expect(try !model().canReload)
    }

    @Test func showsTheAppVersionBuildAndIdentifier() throws {
        let developer = try model()
        #expect(developer.versionText == "1.2")
        #expect(developer.buildText == "7")
        #expect(developer.identifierText == "com.byescaleira.fiscal")
        #expect(developer.installedText == "1.2 (7)")
    }
}
