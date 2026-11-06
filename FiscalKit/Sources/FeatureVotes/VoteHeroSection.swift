import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

extension CGFloat {
    fileprivate static let voteHeroFigureScale: CGFloat = 0.7
}

struct VoteHeroSection: View {
    @Environment(VoteDetailModel.self) private var vote

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceS) {
            VoteScoreboard()
                .background {
                    HeroSurface(.vote) { VoteBoardBackground() }
                }
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
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let outcome = vote.outcome ?? .pending
        let ink = HeroInk(colorScheme)
        VStack(spacing: .spaceM) {
            VStack(spacing: .space2XS) {
                if colorScheme == .light {
                    Text(verbatim: vote.heroCaption)
                        .font(.chipLabel)
                        .foregroundStyle(ink.secondary)
                } else {
                    Chip(vote.heroCaption, color: ink.primary, shape: .capsule)
                }
                Text(verbatim: vote.title)
                    .font(.titleMedium)
                    .foregroundStyle(ink.primary)
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
                if let layout = vote.plenaryLayout {
                    HeroPlenary(layout: layout)
                } else if let tally = vote.vote?.tally, (tally.total ?? 0) > 0 {
                    TallyChart(
                        segments: [
                            TallyChart.Segment(
                                id: "yes", title: BallotChoice.yes.title,
                                value: Double(tally.yes ?? 0),
                                color: ink.signal(BallotChoice.yes.color)),
                            TallyChart.Segment(
                                id: "no", title: BallotChoice.no.title,
                                value: Double(tally.no ?? 0),
                                color: colorScheme == .dark
                                    ? ink.dimmed : BallotChoice.no.color),
                            TallyChart.Segment(
                                id: "others", title: String(appLocalized: "Others"),
                                value: Double(tally.others ?? 0), color: ink.track,
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
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let ink = HeroInk(colorScheme)
        VStack(spacing: .space2XS) {
            ScoreboardFigure(value, numeric: numeric, scale: .voteHeroFigureScale)
                .foregroundStyle(isDimmed ? ink.secondary : ink.primary)
            StatusCircle(choice.title, symbol: choice.symbol, color: ink.signal(choice.color))
        }
        .frame(maxWidth: .infinity)
    }
}

private struct HeroPlenary: View {
    @Environment(VoteDetailModel.self) private var vote
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ReducesMotion private var reduceMotion
    let layout: HemicycleLayout

    var body: some View {
        let colors = colors(HeroInk(colorScheme))
        VStack(spacing: .spaceM) {
            PlenaryChart(
                layout: layout, colors: colors, requiredYes: vote.plenary?.requiredYes,
                animates: !reduceMotion && !MotionBudget.isConstrained)
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: .space2XS) { items(colors) }
            } else {
                HStack(spacing: .spaceM) { items(colors) }
            }
        }
    }

    private func items(_ colors: PlenaryColors) -> some View {
        ForEach(vote.plenaryLegend) { item in
            HStack(spacing: .space2XS) {
                Circle()
                    .fill(colors.color(for: item.group))
                    .frame(width: .spaceS, height: .spaceS)
                Text(verbatim: item.title)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(colors.ink)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
    }

    private func colors(_ ink: HeroInk) -> PlenaryColors {
        PlenaryColors(
            yes: ink.signal(BallotChoice.yes.color),
            no: .voteNo, other: .voteAbstain,
            absent: colorScheme == .dark ? ink.dimmed : .voteAbsent, track: ink.track,
            ink: ink.secondary)
    }
}

private struct HeroNoScore: View {
    @Environment(VoteDetailModel.self) private var vote
    @Environment(\.colorScheme) private var colorScheme
    let outcome: VoteOutcome

    var body: some View {
        let ink = HeroInk(colorScheme)
        VStack(spacing: .spaceS) {
            Image(systemName: outcome.symbol)
                .font(.icon(.l, weight: .semibold))
            Text(verbatim: outcome.title)
                .font(.chipLabel)
                .textCase(.uppercase)
            Text(verbatim: vote.symbolicText ?? vote.headline)
                .font(.subheadline)
                .foregroundStyle(ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(ink.primary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }
}

private struct HeroCenter: View {
    @ReducesMotion private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
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
        .foregroundStyle(HeroInk(colorScheme).signal(outcome.color))
        .fixedSize()
        .onAppear { if !reduceMotion { hasAppeared = true } }
    }
}

private struct HeroRule: View {
    @Environment(VoteDetailModel.self) private var vote
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: .space2XS) {
            Text(verbatim: vote.quorumText)
                .font(.caption.weight(.semibold))
            if let others = vote.othersText {
                Text(verbatim: others)
                    .font(.caption)
            }
        }
        .foregroundStyle(HeroInk(colorScheme).secondary)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct HeroLastLine: View {
    @Environment(VoteDetailModel.self) private var vote
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let ink = HeroInk(colorScheme)
        HStack(spacing: .spaceS) {
            Capsule()
                .fill(ink.primary)
                .frame(width: .space2XS)
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: vote.headline)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ink.primary)
                Text(verbatim: vote.votersText)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(ink.secondary)
            }
            Spacer(minLength: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
