import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct ComparePicker: View {
    @Environment(CompareModel.self) private var compare

    var body: some View {
        @Bindable var compare = compare
        NavigationStack {
            List {
                Section {
                    ChosenStrip()
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                } footer: {
                    Text(verbatim: compare.choiceText)
                }
                Section {
                    if compare.people.isEmpty {
                        ProgressView("Loading").frame(maxWidth: .infinity)
                    } else {
                        ForEach(compare.pickerResults) { PickerRow(card: $0) }
                    }
                } footer: {
                    Text("In alphabetical order.")
                }
            }
            .fontDesign(.rounded)
            .navigationTitle("Choose people")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .searchable(text: $compare.pickerQuery, prompt: "Name, party, office or state")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Compare") { Task { await compare.confirm() } }
                        .disabled(!compare.canCompare)
                }
            }
        }
    }
}

private struct ChosenStrip: View {
    @Environment(CompareModel.self) private var compare

    var body: some View {
        let chosen = compare.chosen
        HStack(alignment: .center, spacing: .spaceS) {
            slot(0, chosen: chosen)
            Text("vs")
                .font(.title3.weight(.heavy))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            slot(1, chosen: chosen)
        }
        .padding(.vertical, .spaceL)
    }

    @ViewBuilder private func slot(_ index: Int, chosen: [PersonCard]) -> some View {
        Group {
            if index < chosen.count {
                ChosenSlot(card: chosen[index])
            } else {
                EmptySlot()
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ChosenSlot: View {
    @Environment(CompareModel.self) private var compare
    let card: PersonCard

    var body: some View {
        Button {
            compare.toggle(card)
        } label: {
            VStack(spacing: .spaceS) {
                PersonPortrait(
                    slug: card.slug, name: card.name, party: card.party, size: .badgeXL * 2
                )
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .secondary)
                        .font(.icon(.l))
                        .accessibilityHidden(true)
                }
                Text(verbatim: card.name)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .foregroundStyle(Color.primary)
                PartyMark(card.party)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: card.name))
        .accessibilityHint(Text("Removes this person from the comparison"))
    }
}

private struct EmptySlot: View {
    var body: some View {
        VStack(spacing: .spaceXS) {
            Circle()
                .strokeBorder(
                    .tertiary, style: StrokeStyle(lineWidth: .spaceHairline, dash: [.space2XS])
                )
                .frame(width: .badgeXL * 2, height: .badgeXL * 2)
                .overlay {
                    Image(systemName: "plus").font(.title2).foregroundStyle(.secondary)
                }
            Text("Add person")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct PickerRow: View {
    @Environment(CompareModel.self) private var compare
    let card: PersonCard

    var body: some View {
        Button {
            compare.toggle(card)
        } label: {
            HStack(spacing: .spaceM) {
                PersonPortrait(slug: card.slug, name: card.name, party: card.party, size: .badgeM)
                VStack(alignment: .leading, spacing: .spaceHairline) {
                    Text(verbatim: card.name).font(.rowTitle).foregroundStyle(Color.primary)
                    HStack(spacing: .spaceS) {
                        PartyMark(card.party)
                        Text(verbatim: compare.detail(for: card))
                            .font(.rowDetail)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: .spaceS)
                SelectionMark(isSelected: compare.isChosen(card))
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!compare.canToggle(card))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(compare.isChosen(card) ? .isSelected : [])
    }
}
