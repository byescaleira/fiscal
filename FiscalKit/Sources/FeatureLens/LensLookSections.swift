import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import FiscalResource
import SwiftUI

struct LensThemesSection: View {
    @Environment(LensModel.self) private var lens

    var body: some View {
        Section {
            if let tally = lens.tally, lens.showsChart {
                LensThemeBars(tally: tally)
                if let slice = lens.focusedSlice {
                    Text(verbatim: lens.focusTitle(for: slice))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(lens.focusedVotes) { vote in
                        LensFocusedVoteRow(vote: vote)
                    }
                }
            } else {
                if lens.tally != nil {
                    IconRow(
                        "No votes on these topics in the latest update.", symbol: "tray",
                        color: .secondary)
                }
                ForEach(Array(lens.themes.enumerated()), id: \.element) { index, theme in
                    LensThemeOrderRow(theme: theme, index: index)
                }
                .onMove { source, destination in
                    Task { await lens.moveThemes(from: source, to: destination) }
                }
            }
            Button("Change Topics", systemImage: "list.number") { lens.edit(.themes) }
        } header: {
            Text("Your topics").sectionTitle()
        } footer: {
            if lens.showsChart {
                Text(
                    "Ordered by how often each topic shows up in the latest votes of the Chamber and the Senate. Tap a topic to see its votes."
                )
            } else {
                Text(
                    "These topics come first in Today, Votes and Money, in this order. Drag, or touch and hold to move or remove. Nothing is hidden."
                )
            }
        }
    }
}

struct LensLookSection: View {
    @Environment(LensModel.self) private var lens

    var body: some View {
        Section {
            LensLookPreview(palette: lens.palette, theme: lens.themes.first)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
        } header: {
            Text("Your look").sectionTitle()
        } footer: {
            Text(
                "The palette colors buttons and highlights. Charts, scoreboards and politicians keep their own colors."
            )
        }
        Section {
            LensPaletteGrid(
                swatches: lens.paletteGrid, selected: lens.palette,
                suggested: lens.suggestedPalette
            ) { swatch in
                Task { await lens.choose(swatch) }
            }
            .padding(.vertical, .spaceXS)
        } header: {
            Text("Palette").sectionTitle()
        } footer: {
            Text("Mirrored pairs side by side. Never taken from the color of a party.")
        }
        LensArtSection()
        if lens.supportsIcons {
            Section {
                LensIconStrip(
                    inset: .spaceL, icons: lens.iconChoices, selected: lens.appIcon,
                    suggested: lens.suggestedIcon
                ) { icon in
                    Task { await lens.setIcon(icon) }
                }
                .padding(.vertical, .spaceXS)
            } header: {
                Text("App Icon").sectionTitle()
            } footer: {
                Text("One icon for each palette, or the Amazon at dawn.")
            }
        }
    }
}

private struct LensArtSection: View {
    @Environment(LensModel.self) private var lens

    var body: some View {
        Section {
            if lens.collections.count > 1 {
                LensCollectionPicker(
                    inset: .spaceL, collections: lens.collections, isChosen: lens.isChosen(_:),
                    count: { collection in
                        lens.catalog?.works(in: collection.id).count ?? 0
                    }
                ) { collection in
                    Task { await lens.choose(collection) }
                }
            }
            LensArtCarousel(inset: .spaceL, works: lens.collectionWorks)
                .id(lens.collection?.id)
                .padding(.vertical, .spaceXS)
        } header: {
            Text("Art").sectionTitle()
        } footer: {
            Text(
                "Public domain works by Brazilian artists, always with credit. The art dresses your cards; the data stays the same."
            )
        }
    }
}
