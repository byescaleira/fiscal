import FiscalDomain
import Foundation
import Testing

@testable import FiscalData

struct SupportPrivacyTests {
    @Test func theSupportStoreStaysOutOfBackups() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(
                path: "SupportPrivacyTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let database = try FiscalDatabase.open(cloudSync: false, directory: directory)
        try await database.repositories.support.save(SupportChoice(people: ["pessoa-a"]))
        let store = try #require(database.deviceStoreURL)
        #expect(store.lastPathComponent == "Device.store")
        let values = try store.resourceValues(forKeys: [.isExcludedFromBackupKey])
        #expect(values.isExcludedFromBackup == true)
        let synced = directory.appending(path: "Fiscal.store")
        let syncedValues = try synced.resourceValues(forKeys: [.isExcludedFromBackupKey])
        #expect(syncedValues.isExcludedFromBackup != true)
    }

    @Test func theSupportModelIsOnlyInTheLocalStore() async throws {
        let synced = FiscalSchemaV4.cloudModels.map { String(describing: $0) }
        #expect(!synced.contains("SupportEntity"))
        #expect(!synced.contains("LensEntity"))
        #expect(
            FiscalSchemaV4.deviceModels.map { String(describing: $0) } == [
                "SupportEntity", "LensEntity",
            ])
    }

    @Test func theOldModelWasOnlyInTheLocalStore() {
        let synced = FiscalSchemaV2.cloudModels.map { String(describing: $0) }
        #expect(!synced.contains("LensEntity"))
        #expect(FiscalSchemaV2.deviceModels.map { String(describing: $0) } == ["LensEntity"])
    }

    @Test(arguments: [
        (
            "people=pessoa-a,pessoa-b;causes=saude,impostos",
            SupportScenario.chosen(
                SupportChoice(people: ["pessoa-a", "pessoa-b"], causes: [.health, .taxes]))
        ),
        ("people=pessoa-a", .chosen(SupportChoice(people: ["pessoa-a"]))),
        ("causes=saude", .chosen(SupportChoice(causes: [.health]))),
        ("none", SupportScenario.none),
    ])
    func readsTheSupportScenario(name: String, scenario: SupportScenario) {
        #expect(SupportScenario.named(name) == scenario)
    }

    @Test func ignoresUnknownSupportScenarios() {
        #expect(SupportScenario.named("neutral") == nil)
        #expect(SupportScenario.named("left=pessoa-a") == nil)
        #expect(SupportScenario.named("people=") == nil)
        #expect(SupportScenario.named(nil) == nil)
    }

    @Test func theScenarioNeverTouchesTheStore() async throws {
        let choice = SupportChoice(people: ["pessoa-a", "pessoa-b"], causes: [.health])
        let repository = ShowcaseSupportRepository(scenario: .chosen(choice))
        #expect(await repository.support() == choice)
        let empty = ShowcaseSupportRepository(scenario: .none)
        #expect(await empty.support() == nil)
        await empty.save(choice)
        #expect(await empty.support() == choice)
        await empty.reset()
        #expect(await empty.support() == nil)
    }
}
