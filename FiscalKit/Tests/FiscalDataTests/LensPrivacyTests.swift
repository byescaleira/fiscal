import FiscalDomain
import Foundation
import Testing

@testable import FiscalData

struct LensPrivacyTests {
    @Test func theLensStoreStaysOutOfBackups() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "LensPrivacyTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let database = try FiscalDatabase.open(cloudSync: false, directory: directory)
        try await database.repositories.lens.save(
            LensPreset.suggested(for: .center).lens(stance: .center))
        let store = try #require(database.deviceStoreURL)
        #expect(store.lastPathComponent == "Device.store")
        let values = try store.resourceValues(forKeys: [.isExcludedFromBackupKey])
        #expect(values.isExcludedFromBackup == true)
        let synced = directory.appending(path: "Fiscal.store")
        let syncedValues = try synced.resourceValues(forKeys: [.isExcludedFromBackupKey])
        #expect(syncedValues.isExcludedFromBackup != true)
    }

    @Test func theLensModelIsOnlyInTheLocalStore() {
        let synced = FiscalSchemaV1.cloudModels.map { String(describing: $0) }
        #expect(!synced.contains("LensEntity"))
        #expect(FiscalSchemaV1.deviceModels.map { String(describing: $0) } == ["LensEntity"])
    }

    @Test(arguments: [
        ("right", LensScenario.stance(.right)),
        ("centerRight", .stance(.centerRight)),
        ("center", .stance(.center)),
        ("centerLeft", .stance(.centerLeft)),
        ("left", .stance(.left)),
        ("impartial", .stance(.impartial)),
        ("none", .stance(.preferNotToSay)),
        ("setup", .setup),
    ])
    func readsTheLensScenario(name: String, scenario: LensScenario) {
        #expect(LensScenario.named(name) == scenario)
    }

    @Test func ignoresUnknownLensScenarios() {
        #expect(LensScenario.named("neutral") == nil)
        #expect(LensScenario.named(nil) == nil)
    }

    @Test func scenarioLensSkipsTheSetupWithoutTouchingTheStore() async throws {
        let repository = ShowcaseLensRepository(scenario: .stance(.left))
        let lens = try #require(await repository.lens())
        #expect(lens.stance == .left)
        #expect(lens.isComplete)
        #expect(lens.palette == "annatto")
        let setup = ShowcaseLensRepository(scenario: .setup)
        #expect(await setup.lens() == nil)
        await setup.save(lens)
        #expect(await setup.lens() == lens)
        await setup.reset()
        #expect(await setup.lens() == nil)
    }
}
