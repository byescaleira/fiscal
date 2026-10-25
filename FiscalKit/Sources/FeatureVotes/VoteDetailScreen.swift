import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

public struct VoteDetailScreen: View {
    @Environment(VoteDetailModel.self) private var vote

    public init() {}

    public var body: some View {
        PublicDataContent(
            phase: vote.phase, isEmpty: vote.isEmpty, retry: { await vote.load() }
        ) {
            AdaptiveList {
                VoteSummarySection()
                VoteCountSection()
            }
        } empty: {
            VoteDetailEmptyState()
        }
        .fontDesign(.rounded)
        .navigationTitle(vote.title)
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await vote.load() }
    }
}

private struct VoteSummarySection: View {
    @Environment(VoteDetailModel.self) private var vote

    var body: some View {
        if let summary = vote.detail?.vote {
            Section {
                Text(verbatim: summary.plainSummary ?? summary.summary)
                if summary.plainSummary != nil {
                    Text(verbatim: summary.summary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct VoteCountSection: View {
    @Environment(VoteDetailModel.self) private var vote

    var body: some View {
        Section {
            ForEach(vote.counts) { count in
                LabeledContent {
                    Text(verbatim: count.value).monospacedDigit()
                } label: {
                    Text(verbatim: count.title)
                }
            }
        } header: {
            Text("Tally").sectionTitle()
        }
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
