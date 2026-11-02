import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct ProfileVotesSection: View {
    @Environment(ProfileModel.self) private var profile

    var body: some View {
        if !profile.recentVotes.isEmpty {
            ContentBlock(
                title: Text("Recent Votes"),
                footer: [profile.votesTotalText, profile.sourceText(for: ["votes"])]
            ) {
                ForEach(profile.recentVotes) { vote in
                    let share = profile.shareRoute(for: vote)
                    RouteLink(.vote(id: vote.voteId)) {
                        ProfileVoteRow(vote: vote)
                    }
                    .accessibilityLabel(Text(verbatim: profile.voteAccessibility(vote)))
                    .profileRowShare(share, label: Text("Share the vote on \(vote.heading)"))
                    .shareItemMenu(share, label: Text("Share This Vote"))
                }
            }
        }
    }
}

private struct ProfileVoteRow: View {
    @Environment(ProfileModel.self) private var profile
    let vote: PersonVote

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceXS) {
            AdaptiveRow(spacing: .spaceS) {
                Text(verbatim: "\(profile.shortDay(vote.date)) · \(vote.heading)")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                BallotChip(ballot: profile.ballot(vote))
            }
            Text(verbatim: vote.summary)
                .font(.subheadline)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                if let guidance = profile.guidanceText(vote) {
                    Text(verbatim: guidance).font(.caption).foregroundStyle(.tertiary)
                }
                Spacer(minLength: .badgeL)
            }
            .frame(minHeight: .badgeL)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ProfileProposalsSection: View {
    @Environment(ProfileModel.self) private var profile

    var body: some View {
        if !profile.recentProposals.isEmpty {
            ContentBlock(
                title: Text("Proposals"),
                footer: [
                    profile.proposalsTotalText, profile.plainSummaryNote,
                    profile.sourceText(for: ["proposals"]),
                ]
            ) {
                ForEach(profile.recentProposals) { proposal in
                    let share = profile.shareRoute(for: proposal)
                    ProfileProposalRow(proposal: proposal)
                        .profileRowShare(share, label: Text("Share \(proposal.reference)"))
                        .shareItemMenu(share, label: Text("Share This Proposal"))
                }
            }
        }
    }
}

private struct ProfileProposalRow: View {
    @Environment(ProfileModel.self) private var profile
    let proposal: Proposal

    var body: some View {
        RouteLink(profile.proposalRoute(proposal)) {
            VStack(alignment: .leading, spacing: .spaceS) {
                FlowLayout(spacing: .spaceXS) {
                    Text(verbatim: proposal.reference)
                        .font(.chipLabel)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    if let status = profile.proposalStatus(proposal) {
                        Chip(status, color: .secondary)
                    }
                    ForEach(proposal.themes) { theme in
                        HStack(spacing: .space2XS) {
                            Image(systemName: theme.symbol)
                            Text(verbatim: theme.title)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize()
                    }
                }
                Text(verbatim: proposal.plainSummary ?? proposal.summary)
                    .font(.headline)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: .badgeL)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct ProfileSpeechesSection: View {
    @Environment(ProfileModel.self) private var profile

    var body: some View {
        if !profile.recentSpeeches.isEmpty {
            ContentBlock(
                title: Text("Speeches"),
                footer: [profile.speechesTotalText, profile.sourceText(for: ["speeches"])]
            ) {
                ForEach(Array(profile.recentSpeeches.enumerated()), id: \.offset) { _, speech in
                    VStack(alignment: .leading, spacing: .space2XS) {
                        Text(verbatim: "\(SourceFootnote.day(speech.date)) · \(speech.kind)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(verbatim: speech.summary).font(.subheadline)
                        if let url = speech.url {
                            ExternalLink("Read the Speech", destination: url)
                                .font(.footnote)
                        }
                    }
                }
            }
        }
    }
}

extension View {
    fileprivate func profileRowShare(_ route: Route, label: Text) -> some View {
        overlay(alignment: .bottomTrailing) {
            ShareItemButton(route, label: label)
                .padding(.trailing, .spaceXL)
        }
    }
}
