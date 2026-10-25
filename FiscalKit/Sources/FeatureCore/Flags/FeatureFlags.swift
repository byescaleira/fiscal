import FiscalDomain
import Foundation
import Observation
import SwiftUI

@MainActor @Observable
public final class FeatureFlags {
    public private(set) var remote: [String: RemoteFlag]
    public private(set) var overrides: [String: Bool]
    public let bucket: Int
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let source: (any RemoteFlagSource)?

    public init(defaults: UserDefaults = .standard, source: (any RemoteFlagSource)? = nil) {
        self.defaults = defaults
        self.source = source
        let installID = defaults.string(forKey: Key.installID) ?? UUID().uuidString
        defaults.set(installID, forKey: Key.installID)
        bucket = Self.bucket(for: installID)
        remote =
            (defaults.data(forKey: Key.remote)).flatMap {
                try? JSONDecoder().decode([String: RemoteFlag].self, from: $0)
            } ?? [:]
        overrides = defaults.dictionary(forKey: Key.overrides) as? [String: Bool] ?? [:]
    }

    public func isOn(_ flag: FeatureFlag) -> Bool {
        if let value = overrides[flag.rawValue] { return value }
        if let value = remote[flag.rawValue] { return value.isOn && bucket < value.rollout }
        return flag.defaultValue
    }

    public func override(_ flag: FeatureFlag, _ value: Bool?) {
        overrides[flag.rawValue] = value
        defaults.set(overrides, forKey: Key.overrides)
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
        static let overrides = "fiscal.flags.overrides"
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
