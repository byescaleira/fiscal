import FeatureCore
import FiscalDesignSystem
import SwiftUI

public struct VoteDetailScreen: View {
    @Environment(VoteDetailModel.self) private var vote

    public init() {}

    public var body: some View {
        Group {
            if vote.isEmpty {
                VoteDetailEmptyState()
            }
        }
        .fontDesign(.rounded)
        .navigationTitle("Vote")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await vote.load() }
    }
}

private struct VoteDetailEmptyState: View {
    var body: some View {
        EmptyStateView(
            title: "Vote not loaded",
            description:
                "The tally by party and by state, the party guidance and each vote show up here."
        ) {
            IconRow("Yes", symbol: "hand.thumbsup", color: .retroOlive)
            IconRow("No", symbol: "hand.thumbsdown", color: .retroRust)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.groupedBackground)
    }
}
