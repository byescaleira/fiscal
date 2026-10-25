import FeatureCore
import FiscalDesignSystem
import SwiftUI

public struct ItemEditorScreen: View {
    @Environment(ItemEditorModel.self) private var model

    public init() {}

    public var body: some View {
        Form {
            ItemTitleSection()
        }
        .fontDesign(.rounded)
        .readableWidth()
        .navigationTitle(model.screenTitle)
        .toolbar {
            EditorActions(canSave: model.canSave, canRemove: model.canRemove) {
                await model.save()
            } remove: {
                await model.remove()
            }
        }
        .editorLifecycle(model.status) { await model.load() }
    }
}

private struct ItemTitleSection: View {
    @Environment(ItemEditorModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Section {
            TextField("Title", text: $model.title)
                .font(.rowTitle)
                .submitLabel(.done)
        } footer: {
            Text("Give it a short name you'll recognize in the list.")
        }
    }
}
