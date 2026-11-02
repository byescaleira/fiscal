import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct VoteStickyHeader: View {
    @Environment(VoteDetailModel.self) private var vote
    let current: VoteChapter?
    let select: (VoteChapter) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceS) {
            AdaptiveRow(spacing: .spaceM) {
                VStack(alignment: .leading, spacing: .spaceHairline) {
                    Text(verbatim: vote.title)
                        .font(.headline)
                        .lineLimit(1)
                    if let outcome = vote.outcome {
                        Text(verbatim: outcome.title)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: .spaceS)
                if let score = vote.compactScore {
                    VoteCompactScore(score: score)
                }
            }
            .padding(.horizontal, .spaceL)
            .accessibilityElement(children: .combine)
            if vote.chapters.count > 1 {
                ShortcutStrip(
                    items: vote.chapters.map { .init(id: $0, title: $0.title) },
                    current: current, select: select)
            }
        }
        .padding(.vertical, .spaceS)
        .frame(maxWidth: .readableColumn, alignment: .leading)
        .frame(maxWidth: .infinity)
    }
}

struct VoteCompactScore: View {
    let score: String

    var body: some View {
        HStack(spacing: .spaceS) {
            StatusCircle(
                BallotChoice.yes.title, symbol: BallotChoice.yes.symbol,
                color: BallotChoice.yes.color)
            Text(verbatim: score)
                .font(.amountRow)
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize()
            StatusCircle(
                BallotChoice.no.title, symbol: BallotChoice.no.symbol, color: BallotChoice.no.color)
        }
    }
}
