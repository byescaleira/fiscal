import FeatureCore
import FiscalData
import FiscalDesignSystem
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
@Suite(.timeLimit(.minutes(1)))
struct DeveloperModelTests {
    private let name = "DeveloperModelTests.\(UUID().uuidString)"
    private let events = EventLog(subsystem: "DeveloperModelTests", capacity: 20)
    private var defaults: UserDefaults? { UserDefaults(suiteName: name) }
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
            flags: flags, update: update, session: session, info: info, defaults: try suite(),
            events: events)
    }

    private func flags(source: (any RemoteFlagSource)? = nil) throws -> FeatureFlags {
        FeatureFlags(
            defaults: try suite(),
            overrides: FlagOverrides(prefix: FeatureFlags.prefix, suiteName: name), source: source)
    }

    @Test func choosesEachFlagInThreeStatesAndRestoresTheDefaults() throws {
        let featureFlags = try flags()
        let developer = try model(flags: featureFlags)
        let choices = try #require(developer.flags)
        #expect(developer.bucket == featureFlags.bucket)
        #expect(choices.states.map(\.key) == FeatureFlag.allCases.map(\.rawValue))
        #expect(choices.states.allSatisfy { $0.source == .default })
        #expect(!choices.hasChanges)

        choices.setChoice(.on, for: FeatureFlag.partyIcons.rawValue)
        choices.setChoice(.off, for: FeatureFlag.guides.rawValue)
        #expect(featureFlags.isOn(.partyIcons))
        #expect(!featureFlags.isOn(.guides))
        #expect(choices.choice(for: FeatureFlag.guides.rawValue) == .off)
        #expect(choices.changedCount == 2)
        #expect(
            try suite().dictionary(forKey: "fiscal.flags.overrides") as? [String: Bool]
                == ["partyIcons": true, "guides": false])

        choices.setChoice(.default, for: FeatureFlag.guides.rawValue)
        #expect(featureFlags.isOn(.guides) == FeatureFlag.guides.defaultValue)
        choices.restoreDefaults()
        #expect(!choices.hasChanges)
        #expect(featureFlags.isOn(.partyIcons) == FeatureFlag.partyIcons.defaultValue)
        #expect(try model().flags == nil)
    }

    @Test func showsTheEventLogFilteredAndClearsIt() throws {
        FiscalEvents.launch.log(to: events)
        FiscalEvents.networkError(status: 403).log(to: events)
        let developer = try model()
        #expect(developer.log.totalCount == 2)

        developer.log.minimumLevel = .error
        #expect(developer.log.entries.map(\.message) == ["Network error, HTTP status 403"])
        #expect(developer.log.text.contains("data: Network error, HTTP status 403"))

        developer.log.clear()
        #expect(events.entries.isEmpty)
        #expect(!developer.log.isConfirmingClear)
    }

    @Test func diagnosticsListTheFlagsAndTheEvents() throws {
        FiscalEvents.offlinePack(files: 3).log(to: events)
        let developer = try model(flags: try flags())
        developer.flags?.setChoice(.on, for: FeatureFlag.partyIcons.rawValue)
        let text = developer.diagnostics.text
        #expect(text.contains("partyIcons: on (local)"))
        #expect(text.contains("guides: on (default)"))
        #expect(text.contains("Offline pack refreshed, 3 files"))
        #expect(developer.diagnostics.report.flags.count == FeatureFlag.allCases.count)
    }

    @Test func describesTheLayoutTheWindowMeasures() throws {
        let developer = try model()
        let flat = developer.layout(
            LayoutContext(size: CGSize(width: 402, height: 874), isHorizontallyCompact: true))
        #expect(flat.sizeText == "402 × 874 pt")
        #expect(flat.postureText == String(appLocalized: "Flat"))
        #expect(flat.divisionsText == String(appLocalized: "None"))
        #expect(flat.verticalBarText == String(appLocalized: "None"))

        let standing = developer.layout(
            LayoutContext(
                size: CGSize(width: 800, height: 600), isHorizontallyCompact: false,
                verticalBarEdge: .trailing,
                divisions: [CGRect(x: 390, y: 0, width: 20, height: 600)]))
        #expect(standing.postureText == String(appLocalized: "Folded, side by side"))
        #expect(standing.divisionsText == "(390, 0) 20 × 600 pt")
        #expect(standing.verticalBarText == String(appLocalized: "Trailing"))

        let lying = developer.layout(
            LayoutContext(
                size: CGSize(width: 600, height: 800), isHorizontallyCompact: true,
                verticalBarEdge: .leading,
                divisions: [CGRect(x: 0, y: 390, width: 600, height: 20)]))
        #expect(lying.postureText == String(appLocalized: "Folded, stacked"))
        #expect(lying.verticalBarText == String(appLocalized: "Leading"))
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

    @Test func keepsTheKeysThatHoldData() {
        #expect(DeveloperModel.dataKeys.contains(HomePlace.mineKey))
        #expect(DeveloperModel.dataKeys.contains("fiscal.search.investigations"))
        #expect(
            DeveloperModel.dataKeys.allSatisfy { $0.hasPrefix(DeveloperModel.preferencePrefix) })
    }

    @Test func reloadsTheSessionAndTheRemoteFlags() async throws {
        let source = FakeFlagSource()
        let featureFlags = try flags(source: source)
        let session = SessionModel(
            repositories: try FiscalDatabase.open(inMemory: true).repositories)
        let developer = try model(flags: featureFlags, session: session)
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
