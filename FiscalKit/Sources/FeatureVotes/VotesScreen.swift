import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

public struct VotesScreen: View {
    @Environment(VotesModel.self) private var votes

    public init() {}

    public var body: some View {
        PublicDataContent(
            phase: votes.phase, isEmpty: votes.isEmpty, retry: { await votes.load() }
        ) {
            AdaptiveList { VotesRecentSection() }
        } empty: {
            VotesEmptyState()
        }
        .fontDesign(.rounded)
        .navigationTitle("Votes")
        .refreshable { await votes.load() }
        .task { await votes.load() }
    }
}

private struct VotesRecentSection: View {
    @Environment(VotesModel.self) private var votes

    var body: some View {
        Section {
            ForEach(votes.votes) { vote in
                RouteLink(.vote(id: vote.id)) {
                    VStack(alignment: .leading, spacing: .space2XS) {
                        Text(verbatim: vote.proposition).font(.rowTitle)
                        Text(verbatim: vote.plainSummary ?? vote.summary)
                            .font(.subheadline)
                        Text(verbatim: votes.detail(for: vote))
                            .font(.rowDetail)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("Latest Floor Votes").sectionTitle()
        }
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
