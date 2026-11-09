import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct VoteScoreRow: View {
    @Environment(VotesModel.self) private var votes
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let vote: VoteSummary

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceXS) {
            AdaptiveRow(spacing: .spaceS) {
                Text(verbatim: vote.heading)
                    .font(.headline)
                if !dynamicTypeSize.isAccessibilitySize {
                    Spacer(minLength: .spaceS)
                }
                VoteOutcomeLabel(outcome: VoteOutcome(vote))
            }
            Text(verbatim: votes.summary(vote))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
            if let score = votes.compactScore(vote) {
                AdaptiveRow(spacing: .spaceS) {
                    VoteCompactScore(score: score)
                    if let others = votes.othersText(vote) {
                        Text(verbatim: others)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .lineLimit(1)
                            .fixedSize()
                    }
                }
            }
            AdaptiveRow(spacing: .spaceS) {
                Text(verbatim: votes.houseLine(vote))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                if let theme = vote.themes.first {
                    HStack(spacing: .space2XS) {
                        Image(systemName: theme.symbol)
                        Text(verbatim: theme.title)
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
            }
        }
        .padding(.vertical, .spaceXS)
        .frame(maxWidth: .infinity, alignment: .leading)
        .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: votes.accessibility(vote)))
    }
}

private struct VoteOutcomeLabel: View {
    let outcome: VoteOutcome

    var body: some View {
        HStack(spacing: .space2XS) {
            Image(systemName: outcome.symbol)
            Text(verbatim: outcome.title)
                .lineLimit(1)
        }
        .font(.chipLabel)
        .foregroundStyle(outcome.color)
        .fixedSize()
    }
}
