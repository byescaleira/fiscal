import Foundation
import Testing

@testable import FiscalDomain

struct AppGroupTests {
    private func defaults() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: "AppGroupTests.\(UUID().uuidString)"))
    }

    @Test func theOldMinePlaceKeyMovesOnce() throws {
        let defaults = try defaults()
        defaults.set("2927408", forKey: HomePlace.legacyMineKey)
        #expect(HomePlace.migrateLegacyKeys(in: defaults))
        #expect(defaults.string(forKey: HomePlace.mineKey) == "2927408")
        #expect(defaults.object(forKey: HomePlace.legacyMineKey) == nil)
        #expect(HomePlace.chosenUF(in: defaults) == "ba")
        #expect(!HomePlace.migrateLegacyKeys(in: defaults))
    }

    @Test func aNewerChoiceWinsOverTheOldKey() throws {
        let defaults = try defaults()
        defaults.set("sp", forKey: HomePlace.mineKey)
        defaults.set("rj", forKey: HomePlace.legacyMineKey)
        HomePlace.migrateLegacyKeys(in: defaults)
        #expect(defaults.string(forKey: HomePlace.mineKey) == "sp")
        #expect(defaults.object(forKey: HomePlace.legacyMineKey) == nil)
    }

    @Test func everyKeyStartsWithTheAppPrefix() {
        #expect(HomePlace.mineKey.hasPrefix("fiscal."))
        #expect(CloudSyncPreference.key.hasPrefix("fiscal."))
    }

    @Test func cloudSyncStartsOnAndRemembersTheChoice() throws {
        let defaults = try defaults()
        #expect(CloudSyncPreference.isOn(in: defaults))
        CloudSyncPreference.set(false, in: defaults)
        #expect(!CloudSyncPreference.isOn(in: defaults))
    }

    @Test func theManifestIsPublishedInTheAppFolder() throws {
        let container = FileManager.default.temporaryDirectory
            .appending(path: "AppGroupTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: container) }
        let manifest = AppGroupManifest(
            bundle: "com.byescaleira.fiscal", version: "1.0.0 (1)",
            files: [AppReleaseStore.fileName], updatedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        try AppGroup.publish(manifest, in: container)
        let url = container.appending(path: "fiscal/manifest.json")
        #expect(FileManager.default.fileExists(atPath: url.path()))
        #expect(AppGroup.manifests(in: container) == [manifest])
    }
}
