import FeatureCore
import FiscalDesignSystem
import FiscalResource
import SwiftUI

public struct ShareScreen: View {
    @Environment(ShareModel.self) private var model

    public init() {}

    public var body: some View {
        PublicDataContent(
            phase: model.phase, isEmpty: model.isEmpty, retry: { await model.load() }
        ) {
            ShareEditor()
        } empty: {
            ContentUnavailableView(
                "Nothing to share yet", systemImage: "square.and.arrow.up",
                description: Text("This data isn't published yet."))
        }
        .fontDesign(.rounded)
        .navigationTitle("Share")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await model.load() }
    }
}

private struct ShareEditor: View {
    @Environment(ShareModel.self) private var model
    @Environment(\.displayScale) private var displayScale
    @State private var rendered: RenderedCard?

    var body: some View {
        @Bindable var model = model
        ScrollView {
            VStack(spacing: .spaceXL) {
                ShareCardPreview(rendered: rendered, card: model.card)
                Picker("Format", selection: $model.format) {
                    ForEach(ShareFormat.allCases) { format in
                        Text(format.title).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                ShareArtPicker()
                ShareAction(rendered: rendered)
            }
            .padding(.spaceL)
            .readableWidth()
            .frame(maxWidth: .infinity)
        }
        .background(.groupedBackground)
        .task(id: model.card) {
            guard let card = model.card else { return }
            rendered = ShareRenderer.render(card, code: model.code, scale: displayScale)
                .map { RenderedCard(cgImage: $0, scale: displayScale) }
        }
    }
}

private struct ShareCardPreview: View {
    let rendered: RenderedCard?
    let card: ShareCard?

    var body: some View {
        let size = card?.format.size ?? ShareFormat.stories.size
        Group {
            if let rendered {
                rendered.image
                    .resizable()
                    .scaledToFit()
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.subtleFill)
            }
        }
        .aspectRatio(size.width / size.height, contentMode: .fit)
        .clipShape(.rect(cornerRadius: .radiusL))
        .frame(maxHeight: .sharePreviewMax)
        .shadow(color: .black.opacity(.opacityTint), radius: .spaceM, y: .spaceS)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: card?.accessibilityLabel ?? ""))
        .accessibilityAddTraits(.isImage)
    }
}

private struct ShareArtPicker: View {
    @Environment(ShareModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceM) {
            HStack {
                Text("Art")
                    .font(.headline)
                Spacer()
                if let stance = model.badgeStance {
                    LensBadge(stance)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: .spaceL) {
                    ForEach(model.collections) { collection in
                        ShareCollectionStrip(collection: collection)
                    }
                }
                .padding(.vertical, .space2XS)
            }
            .scrollClipDisabled()
            if let artwork = model.artwork {
                Text(verbatim: artwork.credit)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .animation(reduceMotion ? nil : .smooth, value: model.selectedWorkID)
        .sensoryFeedback(.selection, trigger: model.selectedWorkID)
    }
}

private struct ShareCollectionStrip: View {
    @Environment(ShareModel.self) private var model
    let collection: ArtCollection

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceS) {
            Text(verbatim: collection.name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: .spaceS) {
                ForEach(model.works.filter { $0.collection == collection.id }) { work in
                    ShareThumbnail(work: work)
                }
            }
        }
    }
}

private struct ShareThumbnail: View {
    @Environment(ShareModel.self) private var model
    @Environment(\.appTint) private var tint
    let work: ArtWork

    var body: some View {
        let selected = model.isSelected(work)
        Button {
            model.select(work)
        } label: {
            work.image
                .resizable()
                .scaledToFill()
                .frame(width: .shareThumbnail, height: .shareThumbnail)
                .clipShape(.rect(cornerRadius: .radiusS))
                .overlay {
                    RoundedRectangle(cornerRadius: .radiusS)
                        .strokeBorder(selected ? tint : .clear, lineWidth: .spaceHairline)
                }
                .overlay(alignment: .bottomTrailing) {
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, tint)
                            .padding(.space2XS)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: "\(work.title), \(work.artist), \(work.year)"))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct ShareAction: View {
    @Environment(ShareModel.self) private var model
    let rendered: RenderedCard?

    var body: some View {
        VStack(spacing: .spaceM) {
            if let rendered {
                ShareLink(
                    item: rendered.image, subject: Text("Fiscal card"),
                    message: Text(verbatim: model.shareMessage),
                    preview: SharePreview(Text("Fiscal card"), image: rendered.image)
                ) {
                    Label("Share Image", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .primaryButton()
            } else {
                ProgressView("Preparing the image")
            }
            Text(
                "The card carries the official source, the date and the art credit. Your Lens never goes into the image."
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
    }
}
