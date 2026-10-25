import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

enum BoardStyle {
    static let primary = Color.white
    static let secondary = Color.white.opacity(.opacityStrong)
    static let dimmed = Color.white.opacity(.opacitySoft)
    static let track = Color.white.opacity(.opacityTint)
}

struct VoteHeroSection: View {
    @Environment(VoteDetailModel.self) private var vote

    var body: some View {
        Section {
        } header: {
            VoteScoreboard()
                .textCase(nil)
                .padding(.bottom, .spaceS)
        } footer: {
            Text(verbatim: vote.sourceText)
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
                Text(verbatim: vote.heroCaption)
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(BoardStyle.secondary)
                Text(verbatim: vote.title)
                    .font(.headline)
                    .foregroundStyle(BoardStyle.primary)
            }
            .multilineTextAlignment(.center)
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
                        .layoutPriority(1)
                    HeroSide(
                        choice: .no, value: vote.noText, numeric: vote.noValue,
                        isDimmed: outcome == .approved)
                }
            }
            if let tally = vote.vote?.tally, (tally.total ?? 0) > 0 {
                TallyBar(
                    segments: [
                        TallyBar.Segment(
                            id: "yes", value: Double(tally.yes ?? 0), color: BoardStyle.primary),
                        TallyBar.Segment(
                            id: "no", value: Double(tally.no ?? 0), color: BoardStyle.dimmed),
                        TallyBar.Segment(
                            id: "others", value: Double(tally.others ?? 0),
                            color: BoardStyle.track, dashed: true),
                    ], height: .spaceS)
            }
            HeroLastLine()
        }
        .padding(.spaceL)
        .frame(maxWidth: .infinity)
        .background {
            ZStack {
                LinearGradient(
                    colors: [.voteYesBoard, .scoreboard, .voteNoBoard], startPoint: .leading,
                    endPoint: .trailing)
                Color.black.opacity(.opacityTint)
            }
        }
        .clipShape(.rect(cornerRadius: .radiusGroup))
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
            ScoreboardFigure(value, numeric: numeric)
                .foregroundStyle(isDimmed ? BoardStyle.secondary : BoardStyle.primary)
            Label(choice.title.uppercased(with: .app), systemImage: choice.symbol)
                .font(.caption.weight(.heavy))
                .foregroundStyle(BoardStyle.primary)
                .padding(.horizontal, .spaceS)
                .padding(.vertical, .space2XS)
                .background(BoardStyle.track, in: .capsule)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct HeroCenter: View {
    @Environment(VoteDetailModel.self) private var vote
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false
    let outcome: VoteOutcome

    var body: some View {
        VStack(spacing: .space2XS) {
            Image(systemName: outcome.symbol)
                .font(.icon(.l, weight: .semibold))
                .symbolEffect(.bounce, value: hasAppeared)
            Text(verbatim: outcome.title.uppercased(with: .app))
                .font(.caption.weight(.heavy))
            Text(verbatim: vote.quorumText)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(BoardStyle.secondary)
            Text(verbatim: vote.othersText)
                .font(.caption2)
                .foregroundStyle(BoardStyle.secondary)
        }
        .foregroundStyle(BoardStyle.primary)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { if !reduceMotion { hasAppeared = true } }
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
