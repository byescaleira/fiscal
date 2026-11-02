import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

extension CGFloat {
    fileprivate static let voteHeroFigureScale: CGFloat = 0.7
}

enum BoardStyle {
    static let primary = Color.white
    static let secondary = Color.white.opacity(.opacityStrong)
    static let dimmed = Color.white.opacity(.opacitySoft)
    static let track = Color.white.opacity(.opacityTint)
}

struct VoteHeroSection: View {
    @Environment(VoteDetailModel.self) private var vote

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceS) {
            VoteScoreboard()
                .background { VoteBoardBackground() }
                .clipShape(.rect(cornerRadius: .radiusGroup))
            ContentFooter(lines: [vote.sourceText])
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, .spaceL)
        }
    }
}

private struct VoteBoardBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.voteYesBoard, .scoreboard, .voteNoBoard], startPoint: .leading,
                endPoint: .trailing)
            Color.black.opacity(.opacityTint)
        }
    }
}

private struct VoteScoreboard: View {
    @Environment(VoteDetailModel.self) private var vote
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let outcome = vote.outcome ?? .pending
        VStack(spacing: .spaceM) {
            VStack(spacing: .space2XS) {
                Chip(vote.heroCaption, color: BoardStyle.primary, shape: .capsule)
                    .environment(\.colorScheme, .dark)
                Text(verbatim: vote.title)
                    .font(.titleMedium)
                    .foregroundStyle(BoardStyle.primary)
            }
            .multilineTextAlignment(.center)
            if vote.hasScore {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: .spaceM) {
                        HeroSide(choice: .yes, value: vote.yesText, numeric: vote.yesValue)
                        HeroCenter(outcome: outcome)
                        HeroSide(choice: .no, value: vote.noText, numeric: vote.noValue)
                    }
                } else {
                    HStack(alignment: .center, spacing: .spaceS) {
                        HeroSide(
                            choice: .yes, value: vote.yesText, numeric: vote.yesValue,
                            isDimmed: outcome == .rejected)
                        HeroCenter(outcome: outcome)
                        HeroSide(
                            choice: .no, value: vote.noText, numeric: vote.noValue,
                            isDimmed: outcome == .approved)
                    }
                }
                HeroRule()
                if let tally = vote.vote?.tally, (tally.total ?? 0) > 0 {
                    TallyChart(
                        segments: [
                            TallyChart.Segment(
                                id: "yes", title: BallotChoice.yes.title,
                                value: Double(tally.yes ?? 0), color: BoardStyle.primary),
                            TallyChart.Segment(
                                id: "no", title: BallotChoice.no.title,
                                value: Double(tally.no ?? 0),
                                color: BoardStyle.dimmed),
                            TallyChart.Segment(
                                id: "others", title: String(appLocalized: "Others"),
                                value: Double(tally.others ?? 0), color: BoardStyle.track,
                                dashed: true),
                        ], height: .spaceS)
                }
                HeroLastLine()
            } else {
                HeroNoScore(outcome: outcome)
            }
        }
        .padding(.spaceXL)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: vote.accessibilityScore))
    }
}

private struct HeroSide: View {
    let choice: BallotChoice
    let value: String
    let numeric: Double
    var isDimmed = false

    var body: some View {
        VStack(spacing: .space2XS) {
            ScoreboardFigure(value, numeric: numeric, scale: .voteHeroFigureScale)
                .foregroundStyle(isDimmed ? BoardStyle.secondary : BoardStyle.primary)
            StatusCircle(choice.title, symbol: choice.symbol, color: BoardStyle.primary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct HeroNoScore: View {
    @Environment(VoteDetailModel.self) private var vote
    let outcome: VoteOutcome

    var body: some View {
        VStack(spacing: .spaceS) {
            Image(systemName: outcome.symbol)
                .font(.icon(.l, weight: .semibold))
            Text(verbatim: outcome.title)
                .font(.chipLabel)
                .textCase(.uppercase)
            Text(verbatim: vote.symbolicText ?? vote.headline)
                .font(.subheadline)
                .foregroundStyle(BoardStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(BoardStyle.primary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }
}

private struct HeroCenter: View {
    @ReducesMotion private var reduceMotion
    @State private var hasAppeared = false
    let outcome: VoteOutcome

    var body: some View {
        VStack(spacing: .space2XS) {
            Image(systemName: outcome.symbol)
                .font(.icon(.l, weight: .semibold))
                .quietBounce(value: hasAppeared)
            Text(verbatim: outcome.title)
                .font(.chipLabel)
                .textCase(.uppercase)
                .lineLimit(1)
        }
        .foregroundStyle(BoardStyle.primary)
        .fixedSize()
        .onAppear { if !reduceMotion { hasAppeared = true } }
    }
}

private struct HeroRule: View {
    @Environment(VoteDetailModel.self) private var vote

    var body: some View {
        VStack(spacing: .space2XS) {
            Text(verbatim: vote.quorumText)
                .font(.caption.weight(.semibold))
            if let others = vote.othersText {
                Text(verbatim: others)
                    .font(.caption)
            }
        }
        .foregroundStyle(BoardStyle.secondary)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct HeroLastLine: View {
    @Environment(VoteDetailModel.self) private var vote

    var body: some View {
        HStack(spacing: .spaceS) {
            Capsule()
                .fill(BoardStyle.primary)
                .frame(width: .space2XS)
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: vote.headline)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BoardStyle.primary)
                Text(verbatim: vote.votersText)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(BoardStyle.secondary)
            }
            Spacer(minLength: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
