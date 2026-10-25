import FeatureCore
import FiscalDomain
import Foundation
import Observation

@MainActor @Observable
public final class ItemEditorModel {
    public var title = ""
    public let status = EditorStatus()
    @ObservationIgnored private let id: String?
    @ObservationIgnored private let newID = UUID().uuidString
    @ObservationIgnored private var createdAt = Date.now
    @ObservationIgnored private let repositories: Repositories

    public init(id: String?, repositories: Repositories) {
        self.id = id
        self.repositories = repositories
    }

    public var isNew: Bool { id == nil }

    public var screenTitle: String {
        isNew ? String(appLocalized: "New Item") : String(appLocalized: "Edit Item")
    }

    public var draft: Item {
        Item(id: id ?? newID, title: title, createdAt: createdAt)
    }

    public var canSave: Bool { status.isLoaded && !status.isLocked && draft.isValid }

    public var canRemove: Bool { !isNew && !status.isBusy }

    public func load() async {
        await status.load {
            guard let id else { return }
            guard let record = try await repositories.items.item(id: id) else {
                throw FiscalError.missingRecord
            }
            try Task.checkCancellation()
            title = record.title
            createdAt = record.createdAt
        }
    }

    public func save() async {
        let item = draft
        await status.save { try await repositories.items.save(item) }
    }

    public func remove() async {
        guard let id else { return }
        await status.remove { try await repositories.items.delete(id: id) }
    }
}
