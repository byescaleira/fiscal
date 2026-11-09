import FiscalDomain
import Foundation
import Observation
import SwiftUI

@MainActor @Observable
public final class FeatureFlags {
    nonisolated public static let prefix = "fiscal"

    public private(set) var remote: [String: RemoteFlag]
    public let overrides: FlagOverrides
    public let bucket: Int
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let source: (any RemoteFlagSource)?

    public init(
        defaults: UserDefaults = .standard,
        overrides: FlagOverrides = FlagOverrides(prefix: FeatureFlags.prefix),
        source: (any RemoteFlagSource)? = nil
    ) {
        self.defaults = defaults
        self.overrides = overrides
        self.source = source
        let installID = defaults.string(forKey: Key.installID) ?? UUID().uuidString
        defaults.set(installID, forKey: Key.installID)
        bucket = Self.bucket(for: installID)
        remote =
            (defaults.data(forKey: Key.remote)).flatMap {
                try? JSONDecoder().decode([String: RemoteFlag].self, from: $0)
            } ?? [:]
    }

    public func isOn(_ flag: FeatureFlag) -> Bool {
        if let value = overrides.value(for: flag.rawValue) { return value }
        return remoteValue(flag.rawValue) ?? flag.defaultValue
    }

    public func remoteValue(_ key: String) -> Bool? {
        remote[key].map { $0.isOn && bucket < $0.rollout }
    }

    public var definitions: [FlagDefinition] {
        FeatureFlag.allCases.map {
            FlagDefinition(key: $0.rawValue, title: $0.title, defaultValue: $0.defaultValue)
        }
    }

    public func override(_ flag: FeatureFlag, _ value: Bool?) {
        overrides.set(value, for: flag.rawValue)
    }

    public func refresh() async {
        guard let source, let values = try? await source.fetch() else { return }
        remote = values
        if let data = try? JSONEncoder().encode(values) { defaults.set(data, forKey: Key.remote) }
    }

    static func bucket(for id: String) -> Int {
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in id.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }
        return Int(hash % 100)
    }

    private enum Key {
        static let installID = "fiscal.flags.installID"
        static let remote = "fiscal.flags.remote"
    }
}

extension EnvironmentValues {
    @Entry public var featureFlags: FeatureFlags?
}

extension View {
    public func featureFlags(_ flags: FeatureFlags) -> some View {
        environment(flags).environment(\.featureFlags, flags)
    }
}
