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
            ForEach(race.candidates) { CandidateRow(candidate: $0) }
            if results.canFollow {
                FollowButton(race: race)
            }
        } header: {
            Text(verbatim: results.title(race)).sectionTitle()
        } footer: {
            Text(verbatim: results.updatedText(race))
        }
    }
}

private struct RaceProgress: View {
    @Environment(LiveResultsModel.self) private var results
    @Environment(\.appTint) private var appTint
    let race: Race

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceS) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: results.sectionsPercentText(race))
                    .font(.amountTitle)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: race.sections.percent))
                Spacer()
                Chip(results.statusText(race), color: race.elected == nil ? .secondary : appTint)
            }
            ProgressBar(value: race.sections.percent / 100, color: appTint)
            Text(verbatim: results.sectionsText(race))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, .spaceXS)
        .animation(.smooth, value: race.sections.counted)
        .accessibilityElement(children: .combine)
    }
}

private struct CandidateRow: View {
    @Environment(LiveResultsModel.self) private var results
    @Environment(\.appTint) private var appTint
    let candidate: RaceCandidate

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceS) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: .space2XS) {
                    HStack(spacing: .spaceXS) {
                        Text(verbatim: candidate.name).font(.rowTitle)
                        if candidate.elected {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(appTint)
                                .accessibilityLabel("Elected")
                        }
                    }
                    Text(verbatim: "\(candidate.party) · \(candidate.number)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: .space2XS) {
                    Text(verbatim: results.percentText(candidate))
                        .font(.amountRow)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: candidate.percent))
                    Text(verbatim: results.votesText(candidate))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            ProgressBar(value: candidate.percent / 100, color: appTint)
        }
        .padding(.vertical, .spaceXS)
        .animation(.smooth, value: candidate.votes)
        .accessibilityElement(children: .combine)
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
        .disabled(results.changing.contains(race.id) || race.final && !following)
    }
}
