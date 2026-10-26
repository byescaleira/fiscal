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
                ShareFormatChooser(selection: $model.format)
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
    @Environment(\.appTint) private var tint
    @State private var collectionID: ArtCollection.ID?

    var body: some View {
        let collections = model.collections
        let current = collectionID ?? model.selectedWork?.collection ?? collections.first?.id
        VStack(alignment: .leading, spacing: .spaceM) {
            HStack {
                Text("Art").font(.title3.weight(.bold))
                Spacer()
                if let stance = model.badgeStance {
                    LensBadge(stance)
                }
            }
            HStack(spacing: .spaceS) {
                ForEach(collections) { collection in
                    let isOn = collection.id == current
                    Button {
                        collectionID = collection.id
                    } label: {
                        Text(verbatim: collection.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isOn ? AnyShapeStyle(.white) : AnyShapeStyle(tint))
                            .padding(.horizontal, .spaceM)
                            .padding(.vertical, .spaceS)
                            .background(
                                isOn
                                    ? AnyShapeStyle(tint)
                                    : AnyShapeStyle(tint.opacity(.opacityTint)),
                                in: .capsule)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: .spaceM) {
                        ForEach(model.works.filter { $0.collection == current }) { work in
                            ShareArtCard(work: work).id(work.id)
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.vertical, .spaceXS)
                }
                .scrollIndicators(.hidden)
                .scrollTargetBehavior(.viewAligned)
                .scrollClipDisabled()
                .onAppear {
                    if let id = model.selectedWorkID { proxy.scrollTo(id, anchor: .center) }
                }
            }
            if let work = model.selectedWork {
                Text(
                    verbatim: "\(work.artist) · \(work.title), \(work.year) · \(work.licenseLabel)"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .contentTransition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .smooth, value: model.selectedWorkID)
        .animation(reduceMotion ? nil : .smooth, value: collectionID)
        .sensoryFeedback(.selection, trigger: model.selectedWorkID)
    }
}

private struct ShareArtCard: View {
    @Environment(ShareModel.self) private var model
    @Environment(\.appTint) private var tint
    let work: ArtWork

    var body: some View {
        let selected = model.isSelected(work)
        Button {
            model.select(work)
        } label: {
            VStack(alignment: .leading, spacing: .spaceXS) {
                work.image
                    .resizable()
                    .scaledToFill()
                    .frame(width: .shareThumbnail * 2, height: .shareThumbnail * 3)
                    .clipShape(.rect(cornerRadius: .radiusM))
                    .overlay {
                        RoundedRectangle(cornerRadius: .radiusM)
                            .strokeBorder(selected ? tint : .clear, lineWidth: .space2XS)
                    }
                    .overlay(alignment: .topTrailing) {
                        if selected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.icon(.m))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, tint)
                                .padding(.spaceXS)
                        }
                    }
                    .shadow(color: .black.opacity(selected ? .opacityTint : 0), radius: .spaceS)
                Text(verbatim: work.artist)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(verbatim: work.title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: .shareThumbnail * 2)
            .scaleEffect(selected ? 1 : 0.94)
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

private struct ShareFormatChooser: View {
    @Binding var selection: ShareFormat
    @Environment(\.appTint) private var tint

    var body: some View {
        HStack(alignment: .bottom, spacing: .spaceXL) {
            ForEach(ShareFormat.allCases) { format in
                let isSelected = selection == format
                Button {
                    selection = format
                } label: {
                    VStack(spacing: .spaceS) {
                        RoundedRectangle(cornerRadius: .spaceXS, style: .continuous)
                            .fill(isSelected ? tint.opacity(.opacityTint) : Color.clear)
                            .strokeBorder(
                                isSelected ? tint : Color.secondary, lineWidth: .spaceHairline
                            )
                            .frame(
                                width: .badgeXL * format.size.width / format.size.height,
                                height: .badgeXL)
                        Text(format.title)
                            .font(.footnote.weight(isSelected ? .bold : .regular))
                            .foregroundStyle(
                                isSelected ? AnyShapeStyle(tint) : AnyShapeStyle(.secondary))
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(format.title))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity)
        .sensoryFeedback(.selection, trigger: selection)
        .animation(.snappy, value: selection)
    }
}
