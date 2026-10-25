import FeatureCore
import FiscalDesignSystem
import SwiftUI

public struct VotesScreen: View {
    @Environment(VotesModel.self) private var votes

    public init() {}

    public var body: some View {
        Group {
            if votes.isEmpty {
                VotesEmptyState()
            }
        }
        .fontDesign(.rounded)
        .navigationTitle("Votes")
        .task { await votes.load() }
    }
}

private struct VotesEmptyState: View {
    var body: some View {
        EmptyStateView(
            title: "No votes yet",
            description:
                "The latest floor votes of the Chamber and the Senate show up here, with who voted how."
        ) {
            IconRow("Chamber of Deputies", symbol: "building.columns", color: .retroDenim)
            IconRow("Federal Senate", symbol: "building.columns", color: .retroTeal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.groupedBackground)
    }
}
