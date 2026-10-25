import FiscalDesignSystem
import SwiftUI

public struct EditorActions: ToolbarContent {
    @Environment(\.appTint) private var appTint

    private let canSave: Bool
    private let canRemove: Bool
    private let save: @MainActor () async -> Void
    private let remove: @MainActor () async -> Void

    public init(
        canSave: Bool, canRemove: Bool, save: @escaping @MainActor () async -> Void,
        remove: @escaping @MainActor () async -> Void
    ) {
        self.canSave = canSave
        self.canRemove = canRemove
        self.save = save
        self.remove = remove
    }

    public var body: some ToolbarContent {
        ToolbarItemGroup {
            if canRemove {
                Button("Delete", systemImage: "trash") { Task { await remove() } }
                    .tint(Color.primary)
            }
            Button("Save", systemImage: "checkmark") { Task { await save() } }
                .prominentButton()
                .disabled(!canSave)
                .tint(canSave ? appTint : .disabled)
        }
    }
}
