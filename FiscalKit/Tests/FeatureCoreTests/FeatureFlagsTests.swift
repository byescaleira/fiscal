import FiscalDomain
import Foundation
import Testing

@testable import FeatureCore

@MainActor
struct FeatureFlagsTests {
    private func defaults() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: "FeatureFlagsTests.\(UUID().uuidString)"))
    }

    @Test func startsFromTheDefaultValue() throws {
        let flags = FeatureFlags(defaults: try defaults())
        for flag in FeatureFlag.allCases {
            #expect(flags.isOn(flag) == flag.defaultValue)
        }
    }

    @Test func overrideWinsAndCanBeCleared() throws {
        let flags = FeatureFlags(defaults: try defaults())
        flags.override(.guides, false)
        #expect(!flags.isOn(.guides))
        flags.override(.guides, nil)
        #expect(flags.isOn(.guides) == FeatureFlag.guides.defaultValue)
    }

    @Test func remoteValueRespectsTheRollout() async throws {
        let off = FeatureFlags(defaults: try defaults(), source: FixedSource(rollout: 0))
        await off.refresh()
        #expect(!off.isOn(.guides))
        let on = FeatureFlags(defaults: try defaults(), source: FixedSource(rollout: 100))
        await on.refresh()
        #expect(on.isOn(.guides))
    }

    @Test func bucketIsStableAcrossLaunches() throws {
        let defaults = try defaults()
        let first = FeatureFlags(defaults: defaults).bucket
        let second = FeatureFlags(defaults: defaults).bucket
        #expect(first == second)
        #expect((0..<100).contains(first))
    }
}

private struct FixedSource: RemoteFlagSource {
    let rollout: Int

    func fetch() async throws -> [String: RemoteFlag] {
        [FeatureFlag.guides.rawValue: RemoteFlag(isOn: true, rollout: rollout)]
    }
}
