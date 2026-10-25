import FeatureCore
import FiscalDesignSystem
import SwiftUI

public struct ArtistsScreen: View {
    @Environment(ArtistsModel.self) private var artists

    public init() {}

    public var body: some View {
        Group {
            if artists.isEmpty {
                ArtistsEmptyState()
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
