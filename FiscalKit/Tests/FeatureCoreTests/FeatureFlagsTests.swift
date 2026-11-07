import FiscalDomain
import Foundation
import Testing

@testable import FeatureCore

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct FeatureFlagsTests {
    private struct Store {
        let suite = "FeatureFlagsTests.\(UUID().uuidString)"

        func defaults() throws -> UserDefaults {
            try #require(UserDefaults(suiteName: suite))
        }

        @MainActor func flags(source: (any RemoteFlagSource)? = nil) throws -> FeatureFlags {
            FeatureFlags(
                defaults: try defaults(),
                overrides: FlagOverrides(prefix: FeatureFlags.prefix, suiteName: suite),
                source: source)
        }
    }

    @Test func startsFromTheDefaultValue() throws {
        let flags = try Store().flags()
        for flag in FeatureFlag.allCases {
            #expect(flags.isOn(flag) == flag.defaultValue)
        }
    }

    @Test func overrideWinsAndCanBeCleared() throws {
        let flags = try Store().flags()
        flags.override(.guides, false)
        #expect(!flags.isOn(.guides))
        flags.override(.guides, nil)
        #expect(flags.isOn(.guides) == FeatureFlag.guides.defaultValue)
    }

    @Test func keepsTheOverridesSavedBefore() throws {
        let store = Store()
        try store.defaults().set(
            [FeatureFlag.guides.rawValue: false, FeatureFlag.partyIcons.rawValue: true],
            forKey: "fiscal.flags.overrides")
        let flags = try store.flags()
        #expect(flags.overrides.storageKey == "fiscal.flags.overrides")
        #expect(!flags.isOn(.guides))
        #expect(flags.isOn(.partyIcons))

        flags.override(.guides, nil)
        let saved = try store.defaults().dictionary(forKey: "fiscal.flags.overrides")
        #expect(saved as? [String: Bool] == [FeatureFlag.partyIcons.rawValue: true])
    }

    @Test func definesEveryFlagForTheDeveloperPage() throws {
        let definitions = try Store().flags().definitions
        #expect(definitions.map(\.key) == FeatureFlag.allCases.map(\.rawValue))
        #expect(definitions.map(\.title) == FeatureFlag.allCases.map(\.title))
        #expect(definitions.map(\.defaultValue) == FeatureFlag.allCases.map(\.defaultValue))
    }

    @Test func remoteValueRespectsTheRollout() async throws {
        let off = try Store().flags(source: FixedSource(rollout: 0))
        await off.refresh()
        #expect(!off.isOn(.guides))
        #expect(off.remoteValue(FeatureFlag.guides.rawValue) == false)
        let on = try Store().flags(source: FixedSource(rollout: 100))
        await on.refresh()
        #expect(on.isOn(.guides))
        #expect(on.remoteValue(FeatureFlag.guides.rawValue) == true)
        #expect(on.remoteValue(FeatureFlag.partyIcons.rawValue) == nil)
    }

    @Test func bucketIsStableAcrossLaunches() throws {
        let store = Store()
        let first = try store.flags().bucket
        let second = try store.flags().bucket
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
