import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct ProfileVotesSection: View {
    @Environment(ProfileModel.self) private var profile

    var body: some View {
        if !profile.recentVotes.isEmpty {
            ProfileBlock(
                title: Text("Recent Votes"),
                footer: [profile.votesTotalText, profile.sourceText(for: ["votes"])]
            ) {
                ForEach(profile.recentVotes) { vote in
                    RouteLink(.vote(id: vote.voteId)) {
                        ProfileVoteRow(vote: vote)
                    }
                    .accessibilityLabel(Text(verbatim: profile.voteAccessibility(vote)))
                }
            }
        }
    }
}

private struct ProfileVoteRow: View {
    @Environment(ProfileModel.self) private var profile
    let vote: PersonVote

    var body: some View {
        HStack(alignment: .top, spacing: .spaceM) {
            Text(verbatim: profile.shortDay(vote.date))
                .font(.caption.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: .badgeL, alignment: .leading)
            VStack(alignment: .leading, spacing: .space2XS) {
                Text(verbatim: vote.heading)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(verbatim: vote.summary)
                    .font(.subheadline)
                    .lineLimit(3)
                if let guidance = profile.guidanceText(vote) {
                    Text(verbatim: guidance).font(.caption).foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            BallotChip(ballot: profile.ballot(vote))
        }
    }
}

struct ProfileProposalsSection: View {
    @Environment(ProfileModel.self) private var profile

    var body: some View {
        if !profile.recentProposals.isEmpty {
            ProfileBlock(
                title: Text("Proposals"),
                footer: [
                    profile.proposalsTotalText, profile.plainSummaryNote,
                    profile.sourceText(for: ["proposals"]),
                ]
            ) {
                ForEach(profile.recentProposals) { proposal in
                    ProfileProposalRow(proposal: proposal)
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
            }
        }
    }
}

struct ProfileSpeechesSection: View {
    @Environment(ProfileModel.self) private var profile

    var body: some View {
        if !profile.recentSpeeches.isEmpty {
            ProfileBlock(
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

struct ProfileFooter: View {
    let lines: [String?]

    var body: some View {
        VStack(alignment: .leading, spacing: .space2XS) {
            ForEach(Array(lines.compactMap(\.self).enumerated()), id: \.offset) { _, line in
                Text(verbatim: line)
            }
        }
    }
}
