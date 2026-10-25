import FiscalData
import FiscalDomain
import Testing

@testable import FeatureHome

@MainActor
struct ItemEditorModelTests {
    @Test func createsANewItem() async throws {
        let repositories = try FiscalDatabase.open(inMemory: true).repositories
        let editor = ItemEditorModel(id: nil, repositories: repositories)
        await editor.load()
        #expect(!editor.canSave)
        #expect(!editor.canRemove)
        editor.title = "Groceries"
        #expect(editor.canSave)
        await editor.save()
        #expect(editor.status.isSaved)
        #expect(try await repositories.items.items().map(\.title) == ["Groceries"])
    }

    @Test func editsAndRemovesAnExistingItem() async throws {
        let repositories = try FiscalDatabase.open(inMemory: true).repositories
        try await repositories.items.save(Item(id: "a", title: "Old"))
        let editor = ItemEditorModel(id: "a", repositories: repositories)
        await editor.load()
        #expect(editor.title == "Old")
        #expect(editor.canRemove)
        await editor.remove()
        #expect(editor.status.isSaved)
        #expect(try await repositories.items.items().isEmpty)
    }

    @Test func reportsAMissingRecord() async throws {
        let repositories = try FiscalDatabase.open(inMemory: true).repositories
        let editor = ItemEditorModel(id: "missing", repositories: repositories)
        await editor.load()
        #expect(editor.status.error == .missingRecord)
    }
}
