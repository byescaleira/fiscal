import FeatureCore
import FiscalDesignSystem
import FiscalResource
import SwiftUI

struct ShareArtRail: View {
    @Environment(ShareModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceS) {
            ViewThatFits(in: .horizontal) {
                header(showsBadge: model.showsLensBadge)
                header(showsBadge: false)
            }
            ScrollViewReader { proxy in
                EdgeToEdgeRail(.padded(.spaceL), spacing: .spaceS, lazy: true, snaps: false) {
                    ForEach(model.currentWorks) { work in
                        ShareArtThumbnail(work: work).id(work.id)
                    }
                }
                .onAppear {
                    if let id = model.selectedWork?.id { proxy.scrollTo(id, anchor: .center) }
                }
            }
        }
        .animation(reduceMotion ? nil : .smooth, value: model.collectionID)
        .sensoryFeedback(.selection, trigger: model.selectedWorkID)
    }

    private func header(showsBadge: Bool) -> some View {
        HStack(spacing: .spaceM) {
            Text("Art")
                .font(.emphasis(.subheadline, weight: .bold))
                .accessibilityAddTraits(.isHeader)
            if showsBadge {
                LensBadge()
                    .fixedSize()
            }
            Spacer(minLength: .zero)
            ForEach(model.collections) { collection in
                ShareArtCollectionName(collection: collection)
            }
        }
    }
}

private struct ShareArtCollectionName: View {
    @Environment(ShareModel.self) private var model
    let collection: ArtCollection

    var body: some View {
        let selected = collection.id == model.currentCollectionID
        Button {
            model.show(collection.id)
        } label: {
            Text(verbatim: collection.name)
                .font(.footnote.weight(selected ? .bold : .regular))
                .foregroundStyle(selected ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                .lineLimit(1)
                .fixedSize()
                .frame(minHeight: .rowHeight)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct ShareArtThumbnail: View {
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
                .frame(width: .shareArtThumbWidth, height: .shareArtThumbHeight)
                .clipShape(.rect(cornerRadius: .radiusS))
                .overlay {
                    RoundedRectangle(cornerRadius: .radiusS)
                        .strokeBorder(selected ? tint : .clear, lineWidth: .space2XS)
                }
                .overlay(alignment: .topTrailing) {
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.icon(.s))
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
