import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct ProfileVotesSection: View {
    @Environment(ProfileModel.self) private var profile

    var body: some View {
        if !profile.recentVotes.isEmpty {
            Section {
                ForEach(profile.recentVotes) { vote in
                    RouteLink(.vote(id: vote.voteId)) {
                        ProfileVoteRow(vote: vote)
                    }
                    .accessibilityLabel(Text(verbatim: profile.voteAccessibility(vote)))
                }
            } header: {
                Text("Recent Votes").sectionTitle()
            } footer: {
                ProfileFooter(
                    lines: [profile.votesTotalText, profile.sourceText(for: ["votes"])])
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
                Text(verbatim: vote.proposition)
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
        .padding(.vertical, .space2XS)
    }
}

struct ProfileProposalsSection: View {
    @Environment(ProfileModel.self) private var profile

    var body: some View {
        if !profile.recentProposals.isEmpty {
            Section {
                ForEach(profile.recentProposals) { proposal in
                    ProfileProposalRow(proposal: proposal)
                }
            } header: {
                Text("Proposals").sectionTitle()
            } footer: {
                ProfileFooter(
                    lines: [
                        profile.proposalsTotalText,
                        profile.plainSummaryNote,
                        profile.sourceText(for: ["proposals"]),
                    ])
            }
        }
    }
}

private struct ProfileProposalRow: View {
    @Environment(ProfileModel.self) private var profile
    let proposal: Proposal

    var body: some View {
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
                    Label(theme.title, systemImage: theme.symbol)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text(verbatim: proposal.plainSummary ?? proposal.summary)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            DisclosureGroup("Official summary") {
                Text(verbatim: proposal.summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            .font(.footnote)
            if let url = proposal.url {
                Link(destination: url) {
                    Label("Open the Official Page", systemImage: "arrow.up.right.square")
                }
                .font(.footnote)
            }
        }
        .padding(.vertical, .space2XS)
    }
}

struct ProfileSpeechesSection: View {
    @Environment(ProfileModel.self) private var profile

    var body: some View {
        if !profile.recentSpeeches.isEmpty {
            Section {
                ForEach(Array(profile.recentSpeeches.enumerated()), id: \.offset) { _, speech in
                    VStack(alignment: .leading, spacing: .space2XS) {
                        Text(verbatim: "\(SourceFootnote.day(speech.date)) · \(speech.kind)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(verbatim: speech.summary).font(.subheadline)
                        if let url = speech.url {
                            Link(destination: url) {
                                Label("Read the Speech", systemImage: "arrow.up.right.square")
                            }
                            .font(.footnote)
                        }
                    }
                    .padding(.vertical, .space2XS)
                }
            } header: {
                Text("Speeches").sectionTitle()
            } footer: {
                ProfileFooter(
                    lines: [profile.speechesTotalText, profile.sourceText(for: ["speeches"])])
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
