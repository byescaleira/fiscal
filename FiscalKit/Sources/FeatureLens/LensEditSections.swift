import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct LensStanceSection: View {
    @Environment(LensModel.self) private var lens

    var body: some View {
        Section {
            LensEditRow(title: "Side", value: Text(verbatim: lens.stanceTitle)) {
                lens.edit(.stance)
            }
        } header: {
            Text("Your side").sectionTitle()
        } footer: {
            Text("Changing the side keeps your topics and your look.")
        }
    }
}

struct LensOtherSection: View {
    @Environment(LensModel.self) private var lens
    @Environment(\.close) private var close

    var body: some View {
        Section {
            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: .posterWidth / 2 + .badgeXL), spacing: .spaceS)
                ],
                spacing: .spaceS
            ) {
                ForEach(lens.otherStances) { other in
                    Button {
                        lens.preview(other)
                        close()
                    } label: {
                        Label(
                            other.title, systemImage: lens.isPreviewing(other) ? "eye.fill" : "eye"
                        )
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityAddTraits(lens.isPreviewing(other) ? .isSelected : [])
                }
            }
            .padding(.vertical, .spaceXS)
            if lens.isPreviewing {
                Button("Back to Mine", systemImage: "arrow.uturn.backward") { lens.endPreview() }
            }
        } header: {
            Text("Another lens").sectionTitle()
        } footer: {
            Text(verbatim: lens.otherLensFooter)
        }
    }
}

struct LensPrivacySection: View {
    @Environment(LensModel.self) private var lens

    var body: some View {
        Section {
            LensPrivacyCard()
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            if lens.hasLens {
                Button("Delete My Choice", systemImage: "trash", role: .destructive) {
                    lens.isConfirmingErase = true
                }
            }
        } header: {
            Text("Privacy").sectionTitle()
        } footer: {
            Text(
                "The lens is never sent in requests, logs, notifications, shared cards or Spotlight."
            )
        }
    }
}

private struct LensEditRow: View {
    @Environment(\.appTint) private var tint
    let title: LocalizedStringKey
    let value: Text
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: .spaceM) {
                VStack(alignment: .leading, spacing: .space2XS) {
                    Text(title).font(.subheadline).foregroundStyle(.secondary)
                    value.font(.title2.weight(.bold)).foregroundStyle(.primary)
                }
                Spacer(minLength: .zero)
                Text("Change").font(.subheadline.weight(.semibold)).foregroundStyle(tint)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}
