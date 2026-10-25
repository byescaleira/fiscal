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
                            "Recent photos under an open license, used without cropping or new colors.",
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
                if let stance = artists.badgeStance {
                    LensBadge(stance)
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
    let title: LocalizedStringKey
    let footer: LocalizedStringKey
    let sections: [GallerySection]

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceL) {
            VStack(alignment: .leading, spacing: .space2XS) {
                Text(title)
                    .font(.titleMedium)
                    .accessibilityAddTraits(.isHeader)
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(sections) { section in
                GalleryCollection(section: section)
            }
        }
    }
}

private struct GalleryCollection: View {
    let section: GallerySection

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceM) {
            HStack(spacing: .spaceS) {
                Text(verbatim: section.collection.name)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                HStack(spacing: .space2XS) {
                    ForEach(section.collection.palette, id: \.self) { hex in
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: .gallerySwatch, height: .gallerySwatch)
                    }
                }
                .accessibilityHidden(true)
            }
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: .galleryColumn), spacing: .spaceL)],
                alignment: .leading, spacing: .spaceL
            ) {
                ForEach(section.works) { work in
                    ArtworkCard(work: work)
                }
            }
        }
    }
}

private struct ArtworkCard: View {
    let work: ArtWork

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceM) {
            ZStack {
                work.image
                    .resizable()
                    .scaledToFill()
                    .blur(radius: .shareBlur)
                    .opacity(.opacitySoft)
                work.image
                    .resizable()
                    .scaledToFit()
            }
            .frame(maxWidth: .infinity)
            .frame(height: .galleryArtwork)
            .clipShape(.rect(cornerRadius: .radiusM))
            .accessibilityLabel(Text(verbatim: "\(work.title), \(work.artist)"))
            .accessibilityAddTraits(.isImage)
            VStack(alignment: .leading, spacing: .space2XS) {
                Text(verbatim: work.title)
                    .font(.headline)
                Text(verbatim: "\(work.artist) · \(work.artistLife)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(verbatim: "\(work.year) · \(work.holder)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)
            Chip(work.license, color: work.isPublicDomain ? .positive : .info)
                .accessibilityLabel(Text("License: \(work.license)"))
            AdaptiveStack(spacing: .spaceM) {
                Link(destination: work.licenseUrl) {
                    Label("License", systemImage: "doc.text")
                }
                Link(destination: work.sourceUrl) {
                    Label("Source on Commons", systemImage: "arrow.up.right.square")
                }
            }
            .font(.footnote.weight(.semibold))
        }
        .padding(.spaceM)
        .background(.groupedRow, in: .rect(cornerRadius: .radiusL))
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
