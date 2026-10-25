import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

public struct LensScreen: View {
    @Environment(LensModel.self) private var lens
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        @Bindable var lens = lens
        AdaptiveList {
            LensThemesSection()
        }
        .fontDesign(.rounded)
        .navigationTitle("Lens")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar { LensToolbar() }
        .task { await lens.load() }
        .onChange(of: lens.isSaved) { if lens.isSaved { dismiss() } }
        .errorAlert($lens.error)
    }
}

private struct LensThemesSection: View {
    @Environment(LensModel.self) private var lens

    var body: some View {
        Section {
            ForEach(lens.themes) { theme in
                Button {
                    lens.toggle(theme)
                } label: {
                    HStack(spacing: .spaceM) {
                        IconRow(verbatim: theme.title, symbol: theme.symbol, color: .retroTeal)
                        SelectionMark(isSelected: lens.isChosen(theme))
                    }
                }
                .buttonStyle(.plain)
                .disabled(!lens.canToggle(theme))
                .accessibilityAddTraits(lens.isChosen(theme) ? .isSelected : [])
            }
        } header: {
            Text(verbatim: lens.countText).sectionTitle()
        } footer: {
            Text(
                "Choose 3 to 5 topics and Fiscal puts them first. The numbers stay the same for everyone, and your lens never leaves this device."
            )
        }
    }
}

private struct LensToolbar: ToolbarContent {
    @Environment(LensModel.self) private var lens
    @Environment(\.appTint) private var appTint

    var body: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button("Save", systemImage: "checkmark") { Task { await lens.save() } }
                .prominentButton()
                .disabled(!lens.canSave)
                .tint(lens.canSave ? appTint : .disabled)
        }
    }
}
