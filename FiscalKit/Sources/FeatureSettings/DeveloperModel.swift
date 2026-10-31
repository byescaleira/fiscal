import FeatureCore
import FiscalDomain
import Foundation
import Observation

@MainActor @Observable
public final class DeveloperModel {
    public static let preferencePrefix = "fiscal."
    public static let dataKeys: Set<String> = [
        HomePlace.mineKey, "fiscal.search.investigations", "fiscal.search.recent",
    ]
    public static let simulations: [UpdateState?] = [nil, .recommended, .required]

    public private(set) var preferenceCount = 0
    public private(set) var isReloading = false
    public var isConfirmingDelete = false
    public let info: AppInfo
    @ObservationIgnored private let flags: FeatureFlags?
    @ObservationIgnored private let update: AppUpdateModel?
    @ObservationIgnored private let session: SessionModel?
    @ObservationIgnored private let defaults: UserDefaults

    public init(
        flags: FeatureFlags?, update: AppUpdateModel?, session: SessionModel?,
        info: AppInfo = .main, defaults: UserDefaults = .standard
    ) {
        self.flags = flags
        self.update = update
        self.session = session
        self.info = info
        self.defaults = defaults
        countPreferences()
    }

    public var hasFlags: Bool { flags != nil }

    public var bucket: Int { flags?.bucket ?? .zero }

    public func isOn(_ flag: FeatureFlag) -> Bool {
        flags?.isOn(flag) ?? flag.defaultValue
    }

    public func set(_ flag: FeatureFlag, isOn: Bool) {
        flags?.override(flag, isOn)
    }

    public var hasOverrides: Bool { !(flags?.overrides.isEmpty ?? true) }

    public func restoreFlags() {
        for flag in FeatureFlag.allCases { flags?.override(flag, nil) }
    }

    public var canSimulateUpdates: Bool { update.map { !$0.enforces } ?? false }

    public var simulation: UpdateState? {
        get { update?.cache.simulated }
        set { update?.simulate(newValue) }
    }

    public var isChecking: Bool { update?.isChecking ?? false }

    public var installedText: String { update?.installed?.description ?? info.version }

    public var remoteStateText: String { Self.title(of: update?.remoteState ?? .current) }

    public var policyText: String {
        guard let release = update?.cache.release else {
            return String(appLocalized: "No policy read yet")
        }
        let minimum = "\(release.minimumVersion) (\(release.minimumBuild))"
        let recommended = "\(release.recommendedVersion) (\(release.recommendedBuild))"
        return String(appLocalized: "Minimum \(minimum) · Recommended \(recommended)")
    }

    public var lastCheckText: String {
        guard let date = update?.cache.fetchedAt else { return String(appLocalized: "Never") }
        return date.formatted(.dateTime.day().month().hour().minute().locale(.app))
    }

    public func checkNow() async {
        await update?.refresh(force: true)
    }

    public static func title(of simulation: UpdateState?) -> String {
        guard let simulation else { return String(appLocalized: "Real") }
        return title(of: simulation)
    }

    public static func title(of state: UpdateState) -> String {
        switch state {
        case .current: String(appLocalized: "Up to date")
        case .recommended: String(appLocalized: "Update recommended")
        case .required: String(appLocalized: "Update required")
        }
    }

    public var preferencesFooter: String {
        String(
            appLocalized:
                "\(preferenceCount) preferences saved. Deleting them keeps your data; Fiscal uses the defaults from the next launch."
        )
    }

    public func countPreferences() {
        preferenceCount = preferenceKeys.count
    }

    public func confirmDeletePreferences() {
        guard preferenceCount > .zero else { return }
        isConfirmingDelete = true
    }

    public func deletePreferences() {
        for key in preferenceKeys { defaults.removeObject(forKey: key) }
        isConfirmingDelete = false
        countPreferences()
    }

    public var canReload: Bool { session != nil || flags != nil }

    public func reloadData() async {
        guard !isReloading else { return }
        isReloading = true
        defer { isReloading = false }
        session?.reload()
        await flags?.refresh()
    }

    public var versionText: String { info.number }

    public var buildText: String { info.build }

    public var identifierText: String { info.identifier }

    private var preferenceKeys: [String] {
        defaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix(Self.preferencePrefix) && !Self.dataKeys.contains($0) }
            .sorted()
    }
}
