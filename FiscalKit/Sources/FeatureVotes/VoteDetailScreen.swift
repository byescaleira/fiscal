import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

public struct VoteDetailScreen: View {
    @Environment(VoteDetailModel.self) private var vote

    public init() {}

    public var body: some View {
        @Bindable var vote = vote
        PublicDataContent(
            phase: vote.phase, isEmpty: vote.isEmpty, retry: { await vote.load() }
        ) {
            AdaptiveList {
                VoteHeroSection()
                VoteExplainSection()
                VoteSummarySection()
                VoteRepresentativesSection()
                VoteGuidanceSection()
                VotePartySection()
                VoteBallotsSection()
            }
            .searchable(text: $vote.searchText, prompt: Text("Name, party or state"))
        } empty: {
            VoteDetailEmptyState()
        }
        .fontDesign(.rounded)
        .navigationTitle(vote.title)
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar { VoteDetailToolbar() }
        .refreshable { await vote.load() }
        .task { await vote.load() }
    }
}

private struct VoteDetailToolbar: ToolbarContent {
    @Environment(VoteDetailModel.self) private var vote
    @Environment(\.open) private var open
    @Environment(\.navigationSection) private var section

    var body: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button("Share", systemImage: "square.and.arrow.up") {
                open(.share(.vote(id: vote.id)), in: section)
            }
            .disabled(vote.isEmpty)
            .tint(Color.primary)
        }
    }
}

private struct VoteSummarySection: View {
    @Environment(VoteDetailModel.self) private var vote

    var body: some View {
        Section {
            if let plain = vote.plainSummary {
                Text(verbatim: plain)
                    .font(.title3.weight(.semibold))
                    .padding(.vertical, .space2XS)
                DisclosureGroup {
                    Text(verbatim: vote.officialSummary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                } label: {
                    Label("Official text", systemImage: "doc.text")
                }
            } else {
                Text(verbatim: vote.officialSummary)
                    .textSelection(.enabled)
            }
            if !vote.themes.isEmpty {
                VoteThemes()
            }
        } header: {
            AdaptiveRow(spacing: .spaceS) {
                Text("What Changes").sectionTitle()
                Spacer(minLength: .spaceS)
                if let stance = vote.lensStance {
                    LensBadge(stance)
                }
            }
            .textCase(nil)
        } footer: {
            VStack(alignment: .leading, spacing: .space2XS) {
                if vote.plainSummary != nil {
                    Text("Summary in plain words, written from the official text.")
                }
                if let kind = vote.kindText {
                    Text(verbatim: kind)
                }
            }
        }
    }
}

private struct VoteThemes: View {
    @Environment(VoteDetailModel.self) private var vote
    @Environment(\.appTint) private var tint

    var body: some View {
        FlowLayout(spacing: .spaceS) {
            ForEach(vote.themes) { theme in
                HStack(spacing: .space2XS) {
                    Image(systemName: theme.symbol)
                    Text(verbatim: theme.title)
                    if vote.isLensTheme(theme) {
                        Image(systemName: "eyeglasses")
                            .accessibilityLabel(Text("One of your lens topics"))
                    }
                }
                .font(.chipLabel)
                .foregroundStyle(tint)
                .padding(.horizontal, .spaceM)
                .padding(.vertical, .spaceXS)
                .background(tint.opacity(.opacityTint), in: .capsule)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.vertical, .space2XS)
    }
}

private struct VoteDetailEmptyState: View {
    var body: some View {
        EmptyStateView(
            title: "Vote not loaded",
            description:
                "The tally by party and by state, the party guidance and each vote show up here."
        ) {
            IconRow("Yes", symbol: BallotChoice.yes.symbol, color: BallotChoice.yes.color)
            IconRow("No", symbol: BallotChoice.no.symbol, color: BallotChoice.no.color)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.groupedBackground)
    }
}
