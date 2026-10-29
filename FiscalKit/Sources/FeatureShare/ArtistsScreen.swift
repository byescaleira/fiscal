import FeatureCore
import FiscalDesignSystem
import FiscalResource
import SwiftUI

public struct ArtistsScreen: View {
    @Environment(ArtistsModel.self) private var artists

    public init() {}

    public var body: some View {
        Group {
            if artists.hasLoaded && artists.isEmpty {
                ArtistsEmptyState()
            } else {
                ArtistsGallery()
            }
        }
        .navigationTitle("Artists")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await artists.load() }
    }
}

private struct ArtistsGallery: View {
    @Environment(ArtistsModel.self) private var artists

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: .space2XL) {
                ArtistsHero()
                if !artists.openLicense.isEmpty {
                    GalleryGroup(
                        title: "Open license",
                        footer:
                            "Recent photos under an open license, credited and marked as adapted.",
                        shelf: .openLicense)
                }
                if !artists.historical.isEmpty {
                    GalleryGroup(
                        title: "Historical collection",
                        footer:
                            "Public domain works: the author died more than 70 years ago (Law 9,610, art. 41). Each image comes from a public archive.",
                        shelf: .historical)
                }
            }
            .padding(.spaceL)
            .readableWidth()
            .frame(maxWidth: .infinity)
        }
        .background(.plainBackground)
    }
}

private struct ArtistsHero: View {
    @Environment(ArtistsModel.self) private var artists
    @Environment(\.appTint) private var tint

    var body: some View {
        VStack(spacing: .spaceS) {
            HStack(spacing: .spaceS) {
                Chip("COLLECTION", color: tint, shape: .capsule)
                if artists.showsLensBadge {
                    LensBadge()
                }
            }
            Text(artists.workCount, format: .number)
                .font(.amountHero)
                .contentTransition(.numericText(value: Double(artists.workCount)))
            Text("Artists: \(artists.artistCount) · license checked work by work")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, .spaceL)
        .accessibilityElement(children: .combine)
    }
}

private struct GalleryGroup: View {
    @Environment(ArtistsModel.self) private var artists
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.liteMode) private var liteMode
    let title: LocalizedStringKey
    let footer: LocalizedStringKey
    let shelf: GalleryKind

    var body: some View {
        let current = artists.current(on: shelf)
        VStack(alignment: .leading, spacing: .spaceL) {
            VStack(alignment: .leading, spacing: .space2XS) {
                Text(title)
                    .sectionTitle()
                    .accessibilityAddTraits(.isHeader)
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            GalleryChips(sections: artists.sections(on: shelf), current: current?.id) {
                artists.show($0, on: shelf)
            }
            if let current {
                GalleryShelf(section: current).id(current.id)
            }
        }
        .animation(
            systemReduceMotion || liteMode.reducesMotion ? nil : .smooth,
            value: artists.shownCollections[shelf]
        )
        .sensoryFeedback(.selection, trigger: artists.shownCollections[shelf])
    }
}

private struct GalleryChips: View {
    @Environment(\.appTint) private var tint
    let sections: [GallerySection]
    let current: ArtCollection.ID?
    let select: (ArtCollection.ID) -> Void

    var body: some View {
        EdgeToEdgeRail(.padded(.spaceL), spacing: .spaceS, snaps: false) {
            ForEach(sections) { section in
                let isOn = section.id == current
                Button {
                    select(section.id)
                } label: {
                    HStack(spacing: .spaceXS) {
                        HStack(spacing: -.space2XS) {
                            ForEach(section.collection.palette.prefix(3), id: \.self) { hex in
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: .gallerySwatch, height: .gallerySwatch)
                            }
                        }
                        .accessibilityHidden(true)
                        Text(verbatim: section.collection.name)
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(isOn ? AnyShapeStyle(.white) : AnyShapeStyle(tint))
                    .padding(.horizontal, .spaceM)
                    .padding(.vertical, .spaceS)
                    .background(
                        isOn ? AnyShapeStyle(tint) : AnyShapeStyle(tint.opacity(.opacityTint)),
                        in: .capsule)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
            }
        }
    }
}

private struct GalleryShelf: View {
    let section: GallerySection

    var body: some View {
        EdgeToEdgeRail(.padded(.spaceL), spacing: .spaceL, lazy: true) {
            ForEach(section.works) { ArtworkCard(work: $0) }
        }
    }
}

private struct ArtworkCard: View {
    let work: ArtWork

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceM) {
            Color.clear
                .frame(width: .artistCardWidth, height: .artistCardHeight)
                .overlay { work.image.resizable().scaledToFill() }
                .overlay(alignment: .bottomLeading) { ArtworkCaption(work: work) }
                .clipShape(.rect(cornerRadius: .radiusL, style: .continuous))
                .shadow(color: .black.opacity(.opacityTint), radius: .spaceS, y: .space2XS)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text(verbatim: work.imageLabel))
                .accessibilityAddTraits(.isImage)
            VStack(alignment: .leading, spacing: .space2XS) {
                Text(verbatim: work.title)
                    .font(.headline)
                    .lineLimit(2)
                Text(verbatim: "\(work.year) · \(work.holder)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)
            Chip(work.licenseLabel, color: work.isPublicDomain ? .positive : .info)
                .accessibilityLabel(Text("License: \(work.license)"))
            HStack(spacing: .spaceM) {
                Link(destination: work.licenseUrl) {
                    Label("License", systemImage: "doc.text")
                }
                Link(destination: work.sourceUrl) {
                    Label("Source", systemImage: "arrow.up.right.square")
                }
            }
            .font(.footnote.weight(.semibold))
            .labelStyle(.titleAndIcon)
        }
        .frame(width: .artistCardWidth, alignment: .leading)
    }
}

private struct ArtworkCaption: View {
    let work: ArtWork

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceHairline) {
            Text(verbatim: work.artist).font(.subheadline.weight(.bold))
            if let life = work.lifeSpan {
                Text(verbatim: life).font(.caption2)
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.spaceM)
        .padding(.top, .spaceXL)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(.opacityStrong)], startPoint: .top,
                endPoint: .bottom)
        )
    }
}

private struct ArtistsEmptyState: View {
    var body: some View {
        EmptyStateView(
            title: "No artworks yet",
            description:
                "The artists behind the share cards show up here, with each work, its license and a link to the source."
        ) {
            IconRow("Public domain", symbol: "building.columns", color: .retroPlum)
            IconRow("Open license", symbol: "doc.badge.ellipsis", color: .retroMustard)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.plainBackground)
    }
}
