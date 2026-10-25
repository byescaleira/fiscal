import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct VoteScoreRow: View {
    @Environment(VotesModel.self) private var votes
    @Environment(\.appTint) private var tint
    let vote: VoteSummary

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceS) {
            AdaptiveRow(spacing: .spaceS) {
                Text(verbatim: votes.houseLine(vote))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                if let theme = votes.lensTheme(of: vote) {
                    Label(theme.title, systemImage: theme.symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(votes.isLensTheme(theme) ? tint : .secondary)
                        .lineLimit(1)
                }
            }
            Text(verbatim: vote.proposition)
                .font(.headline)
            Text(verbatim: votes.summary(vote))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            ScoreLine(
                vote: vote, yes: votes.yesText(vote), no: votes.noText(vote),
                others: votes.othersText(vote))
            TallyBar(segments: VoteTally.segments(vote.tally), height: .spaceXS)
        }
        .padding(.vertical, .spaceXS)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: votes.accessibility(vote)))
    }
}

struct ScoreLine: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let vote: VoteSummary
    let yes: String
    let no: String
    let others: String

    var body: some View {
        let outcome = VoteOutcome(vote)
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: .spaceS) {
                ScoreSide(choice: .yes, value: yes, alignment: .leading, isLeading: true)
                ScoreSide(choice: .no, value: no, alignment: .leading, isLeading: true)
                OutcomeCenter(outcome: outcome, others: others)
            }
        } else {
            HStack(alignment: .center, spacing: .spaceS) {
                ScoreSide(
                    choice: .yes, value: yes, alignment: .leading, isLeading: true,
                    isDimmed: outcome == .rejected)
                Spacer(minLength: .spaceS)
                OutcomeCenter(outcome: outcome, others: others)
                Spacer(minLength: .spaceS)
                ScoreSide(
                    choice: .no, value: no, alignment: .trailing, isLeading: false,
                    isDimmed: outcome == .approved)
            }
        }
    }
}

private struct ScoreSide: View {
    let choice: BallotChoice
    let value: String
    let alignment: HorizontalAlignment
    let isLeading: Bool
    var isDimmed = false

    var body: some View {
        VStack(alignment: alignment, spacing: 0) {
            Label(choice.title.uppercased(with: .app), systemImage: choice.symbol)
                .font(.caption2.weight(.heavy))
                .foregroundStyle(choice.color)
                .labelStyle(SideLabelStyle(isLeading: isLeading))
            Text(verbatim: value)
                .font(.scoreboardNumber)
                .monospacedDigit()
                .foregroundStyle(isDimmed ? .secondary : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }
}

private struct SideLabelStyle: LabelStyle {
    let isLeading: Bool

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: .space2XS) {
            if isLeading {
                configuration.icon
                configuration.title
            } else {
                configuration.title
                configuration.icon
            }
        }
    }
}

struct OutcomeCenter: View {
    let outcome: VoteOutcome
    let others: String

    var body: some View {
        VStack(spacing: .space2XS) {
            Label(outcome.title, systemImage: outcome.symbol)
                .font(.chipLabel)
                .foregroundStyle(outcome.color)
                .padding(.horizontal, .spaceS)
                .padding(.vertical, .space2XS)
                .background(outcome.color.opacity(.opacityTint), in: .capsule)
                .lineLimit(1)
            Text(verbatim: others)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .fixedSize()
    }
}

struct VoteHighlightRow: View {
    @Environment(VotesModel.self) private var votes
    @Environment(\.appTint) private var tint
    let vote: VoteSummary

    var body: some View {
        let outcome = VoteOutcome(vote)
        AdaptiveRow(spacing: .spaceM) {
            if let theme = votes.lensTheme(of: vote) {
                SymbolBadge(theme.symbol, color: tint, size: .badgeM)
            }
            VStack(alignment: .leading, spacing: .space2XS) {
                Text(verbatim: vote.proposition).font(.headline)
                Text(verbatim: votes.summary(vote))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Label(outcome.title, systemImage: outcome.symbol)
                    .font(.chipLabel)
                    .foregroundStyle(outcome.color)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
