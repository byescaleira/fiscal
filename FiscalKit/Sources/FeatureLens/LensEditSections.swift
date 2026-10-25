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

struct LensThemesSection: View {
    @Environment(LensModel.self) private var lens

    var body: some View {
        Section {
            FlowLayout(spacing: .spaceS) {
                ForEach(lens.themes) { theme in
                    LensThemeChip(theme: theme)
                }
            }
            .padding(.vertical, .spaceXS)
            .accessibilityElement(children: .combine)
            Button("Change Topics", systemImage: "square.grid.2x2") { lens.edit(.themes) }
        } header: {
            Text("Your topics").sectionTitle()
        } footer: {
            Text("These topics come first in Today, Votes and Money. Nothing is hidden.")
        }
    }
}

struct LensLookSection: View {
    @Environment(LensModel.self) private var lens

    var body: some View {
        Section {
            HStack(spacing: .spaceM) {
                if let palette = lens.palette { LensSwatch(swatch: palette) }
                VStack(alignment: .leading, spacing: .space2XS) {
                    Text(verbatim: lens.paletteTitle).font(.headline)
                    if let palette = lens.palette {
                        Text(verbatim: palette.pairText).font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            .accessibilityElement(children: .combine)
            if let collection = lens.collection, let work = lens.leadWork {
                HStack(spacing: .spaceM) {
                    ArtPoster(work: work, width: .artThumb, height: .artThumb, showsCredit: false)
                    VStack(alignment: .leading, spacing: .space2XS) {
                        Text(verbatim: collection.name).font(.headline)
                        Text(verbatim: "\(work.artist) · \(work.caption)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text(verbatim: work.licenseTitle)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
            }
            Button("Change Look", systemImage: "paintpalette") { lens.edit(.look) }
        } header: {
            Text("Your look").sectionTitle()
        } footer: {
            Text(
                "The palette colors buttons and highlights. Charts, scoreboards and politicians keep their own colors."
            )
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

private struct LensThemeChip: View {
    @Environment(\.appTint) private var tint
    let theme: Theme

    var body: some View {
        Label(theme.title, systemImage: theme.symbol)
            .font(.chipLabel)
            .foregroundStyle(tint)
            .padding(.horizontal, .spaceM)
            .padding(.vertical, .spaceS)
            .background(tint.opacity(.opacityTint), in: .capsule)
    }
}
