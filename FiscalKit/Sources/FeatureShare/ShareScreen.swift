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
            EmptyStateView(
                title: "Nothing to share yet", description: "This data isn't published yet."
            ) {
                Image(systemName: "square.and.arrow.up")
                    .font(.icon(.l))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
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
    @Environment(\.portraitArtwork) private var portraits
    @Environment(\.layoutContext) private var context

    var body: some View {
        @Bindable var model = model
        studio
            .background(.plainBackground)
            .safeAreaInset(edge: .bottom) {
                SharePostBar()
            }
            .sharePostSheet($model.postRequest)
            .onDisappear { model.discardExport() }
            .task(id: model.card) {
                model.render(scale: displayScale, portraits: portraits)
            }
    }

    @ViewBuilder private var studio: some View {
        if context.widthClass == .compact {
            ViewThatFits(in: .vertical) {
                VStack(spacing: .spaceM) {
                    ShareCardCarousel()
                        .frame(minHeight: .shareCarouselMinimum)
                    ShareControls()
                }
                ScrollView {
                    VStack(spacing: .spaceM) {
                        ShareCardCarousel()
                            .frame(height: .shareCarouselScrolling)
                        ShareControls()
                    }
                }
            }
            .padding(.top, .spaceS)
        } else {
            HStack(spacing: .spaceL) {
                ShareCardCarousel()
                    .frame(maxWidth: .infinity)
                ScrollView {
                    ShareControls()
                }
                .frame(width: .shareControlsWidth)
            }
            .padding(.vertical, .spaceM)
        }
    }
}

struct ShareArtPicker: View {
    @Environment(ShareModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.liteMode) private var liteMode
    @Environment(\.appTint) private var tint

    private var reduceMotion: Bool { systemReduceMotion || liteMode.reducesMotion }

    var body: some View {
        let current = model.currentCollectionID
        VStack(alignment: .leading, spacing: .spaceM) {
            HStack {
                Text("Art")
                    .sectionTitle()
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if model.showsLensBadge {
                    LensBadge()
                }
            }
            HStack(spacing: .spaceS) {
                ForEach(model.collections) { collection in
                    let isOn = collection.id == current
                    Button {
                        model.show(collection.id)
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
            .scaleEffect(selected ? 1 : 0.94)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: "\(work.title), \(work.artist), \(work.year)"))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
