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
            ShareCompactStudio()
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

private struct ShareCompactStudio: View {
    @State private var controlsHeight: CGFloat = .zero

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: .spaceM) {
                    ShareCardCarousel()
                        .frame(
                            height: max(
                                proxy.size.height - controlsHeight - .spaceM,
                                .shareCarouselMinimum))
                    ShareControls()
                        .onGeometryChange(for: CGFloat.self, of: \.size.height) { height in
                            controlsHeight = height
                        }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
        }
    }
}
