import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct RaceSection: View {
    @Environment(LiveResultsModel.self) private var results
    let race: Race

    var body: some View {
        Section {
            RaceProgress(race: race)
            ForEach(race.candidates) { CandidateRow(candidate: $0, race: race) }
            if results.showsFollow(race) {
                FollowButton(race: race)
            }
        } header: {
            Text(verbatim: results.title(race)).sectionTitle()
        } footer: {
            VStack(alignment: .leading, spacing: .space2XS) {
                if let updated = results.updatedText(race) { Text(verbatim: updated) }
                if !race.final, let off = results.activitiesOffText { Text(verbatim: off) }
            }
        }
    }
}

private struct RaceProgress: View {
    @Environment(LiveResultsModel.self) private var results
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let race: Race

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceS) {
            AdaptiveRow(spacing: .spaceM) {
                Text(verbatim: results.sectionsPercentText(race))
                    .font(.amountTitle)
                    .monospacedDigit()
                    .contentTransition(
                        reduceMotion ? .identity : .numericText(value: race.sections.percent))
                Spacer(minLength: .spaceS)
                Chip(results.statusText(race), color: race.final ? .retroTeal : .secondary)
            }
            ProgressBar(value: race.sections.percent / 100, color: .retroTeal)
            Text(verbatim: results.sectionsText(race))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, .spaceXS)
        .animation(reduceMotion ? nil : .smooth, value: race.sections.counted)
        .accessibilityElement(children: .combine)
    }
}

private struct CandidateRow: View {
    @Environment(LiveResultsModel.self) private var results
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let candidate: RaceCandidate
    let race: Race

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceS) {
            AdaptiveRow(spacing: .spaceM) {
                CandidateName(candidate: candidate, party: results.partyText(candidate))
                Spacer(minLength: .spaceS)
                VStack(alignment: .trailing, spacing: .space2XS) {
                    Text(verbatim: results.percentText(candidate, in: race))
                        .font(.amountRow)
                        .monospacedDigit()
                        .contentTransition(
                            reduceMotion ? .identity : .numericText(value: candidate.percent))
                    Text(verbatim: results.votesText(candidate, in: race))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .contentTransition(
                            reduceMotion ? .identity : .numericText(value: Double(candidate.votes)))
                }
            }
            ProgressBar(
                value: candidate.percent / 100,
                color: PartyPalette.of(
                    party: candidate.party, fallback: results.index(of: candidate, in: race)
                ).primary)
        }
        .padding(.vertical, .spaceXS)
        .animation(reduceMotion ? nil : .smooth, value: candidate.votes)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: results.accessibilityLabel(candidate, in: race)))
    }
}

private struct CandidateName: View {
    let candidate: RaceCandidate
    let party: String

    var body: some View {
        VStack(alignment: .leading, spacing: .space2XS) {
            HStack(spacing: .spaceXS) {
                Text(verbatim: candidate.name).font(.rowTitle)
                if candidate.elected {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Color.retroTeal)
                        .symbolEffect(.bounce, value: candidate.elected)
                }
            }
            Text(verbatim: party)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct FollowButton: View {
    @Environment(LiveResultsModel.self) private var results
    let race: Race

    var body: some View {
        let following = results.isFollowing(race)
        Button {
            Task { await results.toggle(race) }
        } label: {
            Label(
                following ? "Stop Following" : "Follow on Lock Screen",
                systemImage: following ? "lock.slash" : "lock.iphone")
        }
        .disabled(!results.canToggle(race))
        .accessibilityLabel(Text(verbatim: results.followLabel(race)))
        .accessibilityHint("Shows the count on the Lock Screen and in the Dynamic Island.")
    }
}
