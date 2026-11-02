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
            #if os(macOS)
                VSplitView {
                    VoteDetailOverview()
                    VoteBallotsTable()
                }
                .searchable(text: $vote.searchText, prompt: Text("Name, party or state"))
            #else
                VoteDetailOverview()
            #endif
        } empty: {
            VoteDetailEmptyState()
        }
        .navigationTitle(vote.title)
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar { VoteDetailToolbar() }
        .task { await vote.load() }
    }
}

private struct VoteDetailOverview: View {
    @Environment(VoteDetailModel.self) private var vote
    @State private var current: VoteChapter?

    var body: some View {
        RevealPage(
            chapters: vote.chapters,
            onChapter: { current = $0 },
            refresh: { await vote.load() },
            content: { _ in
                VoteHeroSection().revealHero()
                VoteSummarySection().revealChapter(VoteChapter.change)
                VoteExplainSection()
                VoteSameDaySection()
                if vote.hasNames, vote.hasPeopleToFollow {
                    VStack(alignment: .leading, spacing: .space2XL) {
                        VoteSupportSection()
                        VoteRepresentativesSection()
                    }
                    .revealChapter(VoteChapter.ballots)
                }
                if vote.showsParties {
                    VStack(alignment: .leading, spacing: .space2XL) {
                        VotePartySection()
                        VoteGuidanceSection()
                    }
                    .revealChapter(VoteChapter.parties)
                } else if vote.hasScore {
                    VoteGuidanceSection()
                }
                #if !os(macOS)
                    VoteBallotsLink(
                        chapter: vote.hasPeopleToFollow ? nil : VoteChapter.ballots)
                #endif
            },
            bar: { jump, _ in
                VoteStickyHeader(current: current, select: jump)
            })
    }
}

private struct VoteBallotsLink: View {
    @Environment(VoteDetailModel.self) private var vote
    let chapter: VoteChapter?

    var body: some View {
        if let route = vote.ballotsRoute {
            ContentBlock {
                RouteLink(route) {
                    Label {
                        Text(verbatim: vote.ballotsLinkTitle)
                    } icon: {
                        Image(systemName: "person.3")
                    }
                    .font(.rowTitle)
                }
            }
            .revealChapter(chapter ?? VoteChapter.ballots, isActive: chapter != nil)
        } else if let text = vote.noNamesText {
            ContentBlock {
                Text(verbatim: text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
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

    private var footer: [String?] {
        [
            vote.plainSummary == nil
                ? nil
                : String(
                    appLocalized:
                        "Summary in plain words, rewritten automatically from the official text by fixed rules; the official text is the source."
                ),
            vote.kindText,
        ]
    }

    var body: some View {
        ContentBlock(title: Text("What Changes"), footer: footer) {
            if let plain = vote.plainSummary {
                Text(verbatim: plain)
                    .font(.emphasis(.title3, weight: .semibold))
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
                }
                .font(.chipLabel)
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(tint)
                .padding(.horizontal, .spaceM)
                .padding(.vertical, .spaceXS)
                .background(tint.opacity(.opacityTint), in: .capsule)
                .accessibilityElement(children: .combine)
            }
        }
    }
}

struct VoteDetailEmptyState: View {
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
        .background(.plainBackground)
    }
}
