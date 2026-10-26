import FiscalDomain
import Foundation
import SwiftData
import Testing

@testable import FiscalData

struct InvestigationStoreTests {
    private let date = Date(timeIntervalSince1970: 1_792_917_720)
    private let id = UUID()

    private func investigation(
        _ question: String, id: UUID? = nil, pinned: Bool = false, after seconds: TimeInterval = 0
    ) -> SavedInvestigation {
        SavedInvestigation(
            id: id ?? self.id, question: question, pieces: Data("[]".utf8), conclusion: nil,
            keyNumber: nil, isPinned: pinned, createdAt: date,
            updatedAt: date.addingTimeInterval(seconds))
    }

    private func entities(in database: FiscalDatabase) throws -> [InvestigationEntity] {
        try ModelContext(database.modelContainer).fetch(FetchDescriptor<InvestigationEntity>())
    }

    private func insertCloudCopies(
        _ copies: [SavedInvestigation], into database: FiscalDatabase
    ) throws {
        let context = ModelContext(database.modelContainer)
        for copy in copies { context.insert(InvestigationEntity(investigation: copy)) }
        try context.save()
    }

    @Test func savingTwiceKeepsOneRecordWithTheLatestValues() async throws {
        let database = try FiscalDatabase.open(inMemory: true)
        let store = database.store
        try await store.save(investigation("Who spent the most?"))
        try await store.save(investigation("Who spent the most in 2026?", pinned: true, after: 60))
        let saved = try await store.investigations()
        #expect(saved.count == 1)
        #expect(saved.first?.question == "Who spent the most in 2026?")
        #expect(saved.first?.isPinned == true)
        #expect(saved.first?.createdAt == date)
        #expect(try entities(in: database).count == 1)
    }

    @Test func listsNewestFirst() async throws {
        let store = try FiscalDatabase.open(inMemory: true).store
        let older = UUID()
        let newer = UUID()
        try await store.save(investigation("Older", id: older))
        try await store.save(investigation("Newer", id: newer, after: 120))
        #expect(try await store.investigations().map(\.id) == [newer, older])
    }

    @Test func cloudDuplicatesShowOnceWithTheNewestCopy() async throws {
        let database = try FiscalDatabase.open(inMemory: true)
        try insertCloudCopies(
            [investigation("From the iPad"), investigation("From the iPhone", after: 30)],
            into: database)
        let saved = try await database.store.investigations()
        #expect(try entities(in: database).count == 2)
        #expect(saved.count == 1)
        #expect(saved.first?.id == id)
        #expect(saved.first?.question == "From the iPhone")
    }

    @Test func savingUpdatesEveryDuplicate() async throws {
        let database = try FiscalDatabase.open(inMemory: true)
        try insertCloudCopies(
            [investigation("From the iPad"), investigation("From the iPhone", after: 30)],
            into: database)
        try await database.store.save(
            investigation("Renamed on the Mac", pinned: true, after: 90))
        let copies = try entities(in: database)
        #expect(copies.count == 2)
        #expect(copies.allSatisfy { $0.question == "Renamed on the Mac" && $0.isPinned })
        #expect(copies.allSatisfy { $0.updatedAt == date.addingTimeInterval(90) })
    }

    @Test func deletingRemovesEveryDuplicateAndKeepsTheOthers() async throws {
        let database = try FiscalDatabase.open(inMemory: true)
        let other = UUID()
        try insertCloudCopies(
            [
                investigation("From the iPad"), investigation("From the iPhone", after: 30),
                investigation("Another question", id: other),
            ], into: database)
        let store = database.store
        try await store.deleteInvestigation(id: id)
        #expect(try await store.investigations().map(\.id) == [other])
        #expect(try entities(in: database).count == 1)
        try await store.deleteInvestigation(id: UUID())
        #expect(try entities(in: database).count == 1)
    }

    @Test func aRecordWithABrokenIDIsSkipped() async throws {
        let database = try FiscalDatabase.open(inMemory: true)
        let context = ModelContext(database.modelContainer)
        let broken = InvestigationEntity(investigation: investigation("Broken"))
        broken.investigationID = "not-a-uuid"
        context.insert(broken)
        try context.save()
        #expect(try await database.store.investigations().isEmpty)
    }

    @Test func onDeviceStoresDoNotSyncWithTheCloud() async throws {
        let store = try #require(
            try FiscalDatabase.open(inMemory: true).repositories.investigations)
        #expect(await !store.syncsWithCloud())
    }
}
