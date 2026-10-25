import FiscalDomain
import Foundation
import Testing

struct AppReleaseTests {
    private func version(_ text: String) throws -> AppVersion {
        try #require(AppVersion(text))
    }

    private func release(
        minimum: String = "1.0.0", minimumBuild: Int = 60, recommended: String = "1.2.0",
        recommendedBuild: Int = 70
    ) throws -> AppRelease {
        AppRelease(
            minimumVersion: try version(minimum), minimumBuild: minimumBuild,
            recommendedVersion: try version(recommended), recommendedBuild: recommendedBuild)
    }

    @Test(arguments: [
        ("1.10.0", "1.9.2"), ("2.0", "1.99.99"), ("1.0.1", "1.0"), ("10", "9.9.9"),
        ("1.2.10", "1.2.9"),
    ])
    func comparesNumerically(newer: String, older: String) throws {
        #expect(try version(older) < version(newer))
        #expect(!(try version(newer) < version(older)))
    }

    @Test func trailingZerosAreEqual() throws {
        #expect(try version("1.0") == version("1.0.0"))
        #expect(try version("1") == version("1.0"))
        #expect(Set([try version("1.0"), try version("1.0.0")]).count == 1)
        #expect(!(try version("1.0") < version("1.0.0")))
        #expect(try version(" 1.2.3 ").description == "1.2.3")
    }

    @Test(arguments: ["", "1.", ".1", "1..2", "1.2.3.4", "a.b", "1.-2", "1.2b", "１.２", "1 .2"])
    func rejectsMalformedVersions(_ text: String) {
        #expect(AppVersion(text) == nil)
    }

    @Test func versionCodesAsAString() throws {
        let data = try JSONEncoder().encode([try version("1.10.0")])
        #expect(String(decoding: data, as: UTF8.self) == "[\"1.10.0\"]")
        #expect(try JSONDecoder().decode([AppVersion].self, from: data) == [try version("1.10")])
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode([AppVersion].self, from: Data("[\"1.x\"]".utf8))
        }
    }

    @Test func blocksBelowTheMinimumVersionOrBuild() throws {
        let policy = try release()
        #expect(
            policy.state(for: InstalledApp(version: try version("0.9"), build: 99)) == .required)
        #expect(
            policy.state(for: InstalledApp(version: try version("1.5"), build: 59)) == .required)
        #expect(
            policy.state(for: InstalledApp(version: try version("1.0"), build: 60)) == .recommended)
    }

    @Test func recommendsBelowTheRecommendedVersionOrBuild() throws {
        let policy = try release()
        #expect(
            policy.state(for: InstalledApp(version: try version("1.1.9"), build: 80))
                == .recommended)
        #expect(
            policy.state(for: InstalledApp(version: try version("1.2"), build: 69)) == .recommended)
        #expect(
            policy.state(for: InstalledApp(version: try version("1.2.0"), build: 70)) == .current)
        #expect(
            policy.state(for: InstalledApp(version: try version("1.10"), build: 90)) == .current)
        #expect(policy.recommendationID == "1.2.0 (70)")
    }

    @Test func readsTheInstalledAppFromTheBundleInfo() throws {
        let app = try #require(
            InstalledApp(info: ["CFBundleShortVersionString": "1.0", "CFBundleVersion": "66"]))
        #expect(app == InstalledApp(version: try version("1.0.0"), build: 66))
        #expect(app.description == "1.0 (66)")
        #expect(InstalledApp(info: ["CFBundleShortVersionString": "1.0"]) == nil)
        #expect(
            InstalledApp(info: ["CFBundleShortVersionString": "—", "CFBundleVersion": "66"]) == nil)
    }

    @Test func cacheEnforcesOnlyInReleaseAndSimulatesOnlyInDebug() throws {
        let old = InstalledApp(version: try version("0.9"), build: 10)
        var cache = AppReleaseCache(release: try release(), simulated: .recommended)
        #expect(cache.state(for: old, enforces: true) == .required)
        #expect(cache.state(for: old, enforces: false) == .recommended)
        cache.simulated = nil
        #expect(cache.state(for: old, enforces: false) == .current)
        #expect(cache.remoteState(for: old) == .required)
        #expect(cache.state(for: nil, enforces: true) == .current)
        #expect(AppReleaseCache().state(for: old, enforces: true) == .current)
    }

    @Test func storeKeepsTheLastPolicyOnDisk() throws {
        let directory = FileManager.default.temporaryDirectory.appending(
            path: UUID().uuidString)
        let store = AppReleaseStore(directory: directory)
        #expect(store.read() == AppReleaseCache())
        let cache = AppReleaseCache(
            release: try release(), fetchedAt: Date(timeIntervalSince1970: 1_800_000_000))
        try store.write(cache)
        #expect(AppReleaseStore(directory: directory).read() == cache)
        let old = InstalledApp(version: try version("1.0"), build: 1)
        #expect(store.state(for: old, enforces: true) == .required)
        #expect(store.state(for: old, enforces: false) == .current)
        try Data("not json".utf8).write(to: directory.appending(path: AppReleaseStore.fileName))
        #expect(store.read() == AppReleaseCache())
    }

    @Test func platformsMatchCloudKitRecordNames() {
        #expect(AppPlatform.allCases.map(\.rawValue) == ["ios", "macos", "tvos", "visionos"])
    }

    @Test func currentPlatformOnTheTestHost() {
        #if os(macOS)
            #expect(AppPlatform.current == .macos)
        #elseif os(tvOS)
            #expect(AppPlatform.current == .tvos)
        #elseif os(visionOS)
            #expect(AppPlatform.current == .visionos)
        #else
            #expect(AppPlatform.current == .ios)
        #endif
    }
}
