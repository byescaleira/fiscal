import FiscalData
import FiscalDomain
import Foundation
import Testing

@testable import FeatureSearch

@MainActor
struct InvestigationSavedTests {
    private let date = Date(timeIntervalSince1970: 1_792_917_720)

    private func legacy(_ list: [Investigation], key: String = DeviceInvestigations.key) throws
        -> DeviceInvestigations
    {
        let suite = "investigations-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.set(try PublicDataCoding.encoder().encode(list), forKey: key)
        return DeviceInvestigations(suiteName: suite)
    }

    private func store() throws -> any InvestigationRepository {
        try #require(try FiscalDatabase.open(inMemory: true).repositories.investigations)
    }

    private func model(
        _ repository: any InvestigationRepository, legacy: DeviceInvestigations? = nil,
        after seconds: TimeInterval = 0
    ) -> InvestigationModel {
        let now = date.addingTimeInterval(seconds)
        return InvestigationModel(
            service: nil, repository: repository, legacy: legacy, usesModel: false,
            now: { now })
    }

    @Test func importsTheDeviceListOnceAndOrdersPinnedFirst() async throws {
        let repository = try store()
        let pinned = Investigation(
            question: "Pinned", isPinned: true, createdAt: date, updatedAt: date)
        let recent = Investigation(
            question: "Recent", createdAt: date, updatedAt: date.addingTimeInterval(60))
        let device = try legacy([recent, pinned])
        let model = model(repository, legacy: device)
        await model.loadSaved()
        #expect(model.saved.map(\.id) == [pinned.id, recent.id])
        #expect(model.isOnDevice)
        #expect(device.load().isEmpty)
        #expect(try await repository.investigations().count == 2)
    }

    @Test func renamePinAndDeleteReachTheStore() async throws {
        let repository = try store()
        let first = Investigation(question: "First", createdAt: date, updatedAt: date)
        let second = Investigation(
            question: "Second", createdAt: date, updatedAt: date.addingTimeInterval(30))
        let editor = model(repository, after: 120)
        editor.persist(first)
        editor.persist(second)
        editor.rename(first, to: "  First, renamed  ")
        editor.togglePin(second)
        await editor.saving?.value

        let reader = model(repository)
        await reader.loadSaved()
        #expect(reader.saved.map(\.id) == [second.id, first.id])
        #expect(reader.saved.first?.isPinned == true)
        #expect(reader.saved.last?.question == "First, renamed")
        #expect(reader.saved.last?.updatedAt == date.addingTimeInterval(120))

        editor.delete(second)
        await editor.saving?.value
        await reader.loadSaved()
        #expect(reader.saved.map(\.id) == [first.id])
    }

    @Test func theOldDeviceKeyMovesToTheFiscalKey() async throws {
        let repository = try store()
        let old = Investigation(question: "Old key", createdAt: date, updatedAt: date)
        let device = try legacy([old], key: DeviceInvestigations.legacyKey)
        #expect(device.load().map(\.id) == [old.id])
        let model = model(repository, legacy: device)
        await model.loadSaved()
        #expect(model.saved.map(\.id) == [old.id])
        #expect(device.load().isEmpty)
    }

    @Test func renamingAndTheTitleLiveInTheModel() async throws {
        let repository = try store()
        let investigation = Investigation(question: "First", createdAt: date, updatedAt: date)
        let model = model(repository, after: 60)
        model.persist(investigation)
        model.startRenaming(investigation)
        #expect(model.isRenaming)
        #expect(model.renameText == "First")
        model.renameText = "Renamed"
        model.commitRenaming()
        #expect(!model.isRenaming)
        #expect(model.saved.first?.question == "Renamed")

        await model.open(try #require(model.saved.first))
        #expect(model.title == "Renamed")
        #expect(!model.editTitle("Typed"))
        #expect(model.title == "Typed")
        #expect(model.editTitle("Typed\n"))
        #expect(model.title == "Typed")
        model.commitTitle()
        #expect(model.current?.question == "Typed")
        #expect(model.saved.first?.question == "Typed")
    }

    @Test func clearingAnInvestigationRemovesItFromTheStore() async throws {
        let repository = try store()
        let investigation = Investigation(question: "Temporary", createdAt: date, updatedAt: date)
        let model = model(repository)
        model.persist(investigation)
        model.rename(investigation, to: " ")
        await model.saving?.value
        #expect(model.saved.isEmpty)
        #expect(try await repository.investigations().isEmpty)
    }
}
