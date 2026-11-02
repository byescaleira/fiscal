import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct SupportEditor: View {
    @Environment(SupportEditorModel.self) private var editor
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var editor = editor
        NavigationStack {
            AdaptiveList {
                SupportPeopleSection()
                SupportCausesSection()
            }
            .navigationTitle("My Support")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await editor.save() } }
                        .disabled(editor.isSaving)
                }
            }
        }
        .task { await editor.load() }
        .onChange(of: editor.isFinished) { _, finished in
            if finished { dismiss() }
        }
    }
}

private struct SupportPeopleSection: View {
    @Environment(SupportEditorModel.self) private var editor

    var body: some View {
        @Bindable var editor = editor
        Section {
            ForEach(editor.chosen) { SupportPersonChoice(card: $0, isSelected: true) }
            HStack(spacing: .spaceS) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                TextField("Name, party, office or state", text: $editor.query)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                if !editor.query.isEmpty {
                    Button("Clear", systemImage: "xmark.circle.fill") { editor.query = "" }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .frame(minWidth: .badgeL, minHeight: .badgeL)
                        .contentShape(.rect)
                }
            }
            ForEach(editor.results) { SupportPersonChoice(card: $0, isSelected: false) }
            Toggle("Also Follow", isOn: $editor.alsoFollow)
                .font(.subheadline.weight(.semibold))
        } header: {
            SupportEditorHeader(title: "People", count: editor.peopleCount)
        } footer: {
            Text(
                "Support stays on this device. People you follow can go to your iCloud and Spotlight, so following is your choice. Removing someone here does not unfollow."
            )
        }
    }
}

private struct SupportPersonChoice: View {
    @Environment(SupportEditorModel.self) private var editor
    let card: PersonCard
    let isSelected: Bool

    var body: some View {
        Button {
            editor.toggle(card)
        } label: {
            HStack(spacing: .spaceM) {
                PersonPortrait(slug: card.slug, name: card.name, party: card.party)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: .spaceHairline) {
                    Text(verbatim: card.name)
                        .font(.headline)
                        .foregroundStyle(Color.primary)
                    Text(verbatim: "\(card.officeTitle) · \(card.party)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: .spaceS)
                SelectionMark(isSelected: isSelected)
            }
            .contentShape(.rect)
            .privacySensitive()
        }
        .buttonStyle(.plain)
        .disabled(!isSelected && !editor.canAddPerson)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct SupportCausesSection: View {
    @Environment(SupportEditorModel.self) private var editor

    var body: some View {
        Section {
            ForEach(editor.causes) { SupportCauseChoice(cause: $0) }
        } header: {
            SupportEditorHeader(title: "Causes", count: editor.causesCount)
        } footer: {
            Text("A cause is a topic, not a position. Fiscal shows the facts tagged with it.")
        }
    }
}

private struct SupportCauseChoice: View {
    @Environment(SupportEditorModel.self) private var editor
    let cause: Theme

    var body: some View {
        let isSelected = editor.draft.contains(cause)
        Button {
            editor.toggle(cause)
        } label: {
            HStack(spacing: .spaceM) {
                Image(systemName: cause.symbol)
                    .frame(width: .badgeM)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: .spaceHairline) {
                    Text(verbatim: cause.title)
                        .font(.headline)
                        .foregroundStyle(Color.primary)
                    Text(verbatim: cause.coverage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: .spaceS)
                SelectionMark(isSelected: isSelected)
            }
            .contentShape(.rect)
            .privacySensitive()
        }
        .buttonStyle(.plain)
        .disabled(!editor.canToggle(cause))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct SupportEditorHeader: View {
    let title: LocalizedStringKey
    let count: String

    var body: some View {
        HStack {
            Text(title).sectionTitle()
            Spacer(minLength: .spaceS)
            Text(verbatim: count)
                .font(.chipLabel)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize()
        }
    }
}
