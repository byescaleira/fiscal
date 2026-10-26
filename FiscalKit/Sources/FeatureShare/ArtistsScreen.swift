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
        .fontDesign(.rounded)
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
                        sections: artists.openLicense)
                }
                if !artists.historical.isEmpty {
                    GalleryGroup(
                        title: "Historical collection",
                        footer:
                            "Public domain works: the author died more than 70 years ago (Law 9,610, art. 41). Each image comes from a public archive.",
                        sections: artists.historical)
                }
            }
            .padding(.spaceL)
            .readableWidth()
            .frame(maxWidth: .infinity)
        }
        .background(.groupedBackground)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var collectionID: ArtCollection.ID?
    let title: LocalizedStringKey
    let footer: LocalizedStringKey
    let sections: [GallerySection]

    var body: some View {
        let current = sections.first { $0.id == collectionID } ?? sections.first
        VStack(alignment: .leading, spacing: .spaceL) {
            VStack(alignment: .leading, spacing: .space2XS) {
                Text(title)
                    .font(.title3.weight(.bold))
                    .accessibilityAddTraits(.isHeader)
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            GalleryChips(sections: sections, current: current?.id) { collectionID = $0 }
            if let current {
                GalleryShelf(section: current).id(current.id)
            }
        }
        .animation(reduceMotion ? nil : .smooth, value: collectionID)
        .sensoryFeedback(.selection, trigger: collectionID)
    }
}

private struct GalleryChips: View {
    @Environment(\.appTint) private var tint
    let sections: [GallerySection]
    let current: ArtCollection.ID?
    let select: (ArtCollection.ID) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: .spaceS) {
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
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }
}

private struct GalleryShelf: View {
    let section: GallerySection

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: .spaceL) {
                ForEach(section.works) { ArtworkCard(work: $0) }
            }
            .scrollTargetLayout()
            .padding(.vertical, .spaceXS)
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .scrollClipDisabled()
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
                .accessibilityLabel(Text(verbatim: "\(work.title), \(work.artist)"))
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
        .accessibilityHidden(true)
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
        .background(.groupedBackground)
    }
}
