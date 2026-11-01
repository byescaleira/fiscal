import FeatureCore
import FiscalDesignSystem
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
            .safeAreaBar(edge: .bottom) {
                ShareStatusBar()
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    SharePostButton()
                }
            }
            .sharePostSheet($model.postRequest)
            .onDisappear { model.discardExport() }
            .task(id: model.card) {
                model.render(scale: displayScale, portraits: portraits)
            }
    }

    @ViewBuilder private var studio: some View {
        if context.widthClass == .compact {
            ShareStudioLayout {
                ShareCardCarousel()
                ShareControlsPanel()
            }
            .padding(.top, .spaceS)
        } else {
            HStack(spacing: .spaceL) {
                ShareCardCarousel()
                    .frame(maxWidth: .infinity)
                ShareControlsPanel()
                    .frame(width: .shareControlsWidth)
            }
            .padding(.top, .spaceM)
        }
    }
}

private struct ShareStudioLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
    ) {
        guard let preview = subviews.first, let panel = subviews.last else { return }
        let height = bounds.height * .shareStudioPreviewShare
        preview.place(
            at: bounds.origin, proposal: ProposedViewSize(width: bounds.width, height: height))
        panel.place(
            at: CGPoint(x: bounds.minX, y: bounds.minY + height + .spaceM),
            proposal: ProposedViewSize(
                width: bounds.width, height: bounds.height - height - .spaceM))
    }
}

private struct ShareControlsPanel: View {
    private let panelShape = UnevenRoundedRectangle(
        topLeadingRadius: .radiusGroup, topTrailingRadius: .radiusGroup)

    var body: some View {
        ScrollView {
            ShareControls()
                .padding(.vertical, .spaceL)
        }
        .scrollIndicators(.hidden)
        .mask {
            panelShape
                .ignoresSafeArea(edges: .bottom)
        }
        .background {
            panelShape
                .fill(.plainRow)
                .ignoresSafeArea(edges: .bottom)
        }
    }
}
