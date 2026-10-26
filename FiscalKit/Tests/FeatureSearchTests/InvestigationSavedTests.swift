import FiscalData
import FiscalDomain
import Foundation
import Testing

@testable import FeatureSearch

@MainActor
struct InvestigationSavedTests {
    private let date = Date(timeIntervalSince1970: 1_792_917_720)

    private func legacy(_ list: [Investigation]) throws -> DeviceInvestigations {
        let defaults = try #require(UserDefaults(suiteName: "investigations-\(UUID().uuidString)"))
        defaults.set(
            try PublicDataCoding.encoder().encode(list), forKey: DeviceInvestigations.key)
        return DeviceInvestigations(defaults: defaults)
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
