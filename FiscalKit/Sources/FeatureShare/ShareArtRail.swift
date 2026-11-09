import FeatureCore
import FiscalDesignSystem
import FiscalResource
import SwiftUI

struct ShareArtRail: View {
    @Environment(ShareModel.self) private var model
    @ReducesMotion private var reduceMotion
    @Environment(\.appTint) private var tint

    var body: some View {
        let current = model.currentCollectionID
        VStack(alignment: .leading, spacing: .spaceM) {
            Text("Art")
                .sectionTitle()
                .accessibilityAddTraits(.isHeader)
            AdaptiveStack(spacing: .spaceS) {
                ForEach(model.collections) { collection in
                    let isOn = collection.id == current
                    Button {
                        model.show(collection.id)
                    } label: {
                        Text(verbatim: collection.name)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .fixedSize()
                            .foregroundStyle(isOn ? AnyShapeStyle(.white) : AnyShapeStyle(tint))
                            .padding(.horizontal, .spaceM)
                            .padding(.vertical, .spaceS)
                            .background(
                                isOn
                                    ? AnyShapeStyle(tint)
                                    : AnyShapeStyle(tint.opacity(.opacityTint)),
                                in: .capsule
                            )
                            .frame(minHeight: .rowHeight)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
            ScrollViewReader { proxy in
                EdgeToEdgeRail(.padded(.spaceL)) {
                    ForEach(model.currentWorks) { work in
                        ShareArtCard(work: work).id(work.id)
                    }
                }
                .onAppear {
                    if let id = model.selectedWorkID { proxy.scrollTo(id, anchor: .center) }
                }
            }
            if let credit = model.selectedCredit {
                Text(verbatim: credit)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .contentTransition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .smooth, value: model.selectedWorkID)
        .animation(reduceMotion ? nil : .smooth, value: model.collectionID)
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
            .contentShape(.rect)
            .scaleEffect(selected ? 1 : 0.94)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: "\(work.title), \(work.artist), \(work.year)"))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
