import CoreGraphics
import FiscalDesignSystem
import SwiftUI

struct ShareVictoryPoster: View {
    let card: ShareCard
    let victory: ShareVictory
    let code: CGImage?

    var body: some View {
        let format = card.format
        VStack(alignment: .leading, spacing: .zero) {
            Spacer(minLength: .zero)
            ShareVictoryHero(victory: victory, format: format)
            Spacer(minLength: format.victorySpacing)
            VStack(alignment: .leading, spacing: format.victorySpacing) {
                if let runner = victory.runnerUp {
                    ShareVictoryRunner(runner: runner, format: format)
                }
                ShareVictoryBallots(ballots: victory.ballots)
                ShareVictoryFooter(card: card, context: victory.context, code: code)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(format.margin)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background { ShareVictoryField(party: victory.winner.party) }
    }
}

private struct ShareVictoryField: View {
    let party: String

    var body: some View {
        let palette = PartyPalette.of(party: party)
        ZStack {
            LinearGradient(
                colors: [palette.primary, palette.secondary], startPoint: .topLeading,
                endPoint: .bottomTrailing)
            Color.scoreboard.opacity(.opacitySoft)
            LinearGradient(
                colors: [.clear, Color.scoreboard.opacity(.opacitySoft)], startPoint: .center,
                endPoint: .bottom)
        }
        .accessibilityHidden(true)
    }
}

struct ShareVictoryHero: View {
    let victory: ShareVictory
    let format: ShareFormat

    var body: some View {
        if format.victoryIsSideBySide {
            VStack(alignment: .leading, spacing: .spaceS) {
                HStack(alignment: .center, spacing: .spaceL) {
                    ShareVictoryPortrait(face: victory.winner, format: format)
                    VStack(alignment: .leading, spacing: .spaceXS) {
                        ShareVictoryChip(format: format)
                        name.multilineTextAlignment(.leading)
                        score
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                statement.multilineTextAlignment(.leading)
            }
        } else {
            VStack(spacing: format.victorySpacing) {
                ShareVictoryPortrait(face: victory.winner, format: format)
                    .padding(.bottom, .spaceXS)
                ShareVictoryChip(format: format)
                name.multilineTextAlignment(.center)
                score
                statement.multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var name: some View {
        Text(verbatim: victory.winner.name)
            .font(.posterTitle(format.victoryName))
            .lineLimit(2)
            .minimumScaleFactor(.posterShrink)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var score: some View {
        HStack(alignment: .center, spacing: .spaceM) {
            ShareVictoryParty(party: victory.winner.party, size: format.victoryParty)
            ShareFigure(value: victory.percent, size: format.victoryPercent)
                .fixedSize()
        }
    }

    private var statement: some View {
        Text(verbatim: victory.statement)
            .font(format.victoryStatement)
            .foregroundStyle(Color.posterSecondary)
            .lineLimit(2)
            .minimumScaleFactor(.shareTextShrink)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct ShareVictoryPortrait: View {
    let face: ShareFace
    let format: ShareFormat

    var body: some View {
        let size = format.victoryPortrait
        let palette = PartyPalette.of(party: face.party)
        PersonPortrait(slug: face.slug, name: face.name, party: face.party, size: size)
            .overlay { Circle().strokeBorder(.white, lineWidth: format.victoryRing) }
            .overlay(alignment: .topTrailing) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.posterSeal(format.victorySeal))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color.scoreboardAccent)
            }
            .background {
                CelebrationConfetti(colors: [palette.primary, palette.secondary, .white])
                    .frame(width: size * .posterVictoryHalo, height: size * .posterVictoryHalo)
            }
    }
}

private struct ShareVictoryChip: View {
    let format: ShareFormat

    var body: some View {
        Text("ELECTED")
            .font(format.victoryChip)
            .tracking(.posterTracking)
            .padding(.horizontal, .spaceM)
            .padding(.vertical, .space2XS)
            .background(.white.opacity(.opacityTint), in: .capsule)
    }
}

private struct ShareVictoryParty: View {
    let party: String
    let size: CGFloat

    var body: some View {
        Text(verbatim: party.uppercased())
            .font(.posterPartyTag(size))
            .tracking(.posterTracking)
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(.opacitySoft), radius: .spaceHairline)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, size * .posterVictoryTagWidth)
            .padding(.vertical, size * .posterVictoryTagHeight)
            .background {
                PartyStripes(palette: PartyPalette.of(party: party))
                    .clipShape(.capsule)
            }
            .overlay {
                Capsule().strokeBorder(.white.opacity(.opacitySoft), lineWidth: .spaceHairline)
            }
            .accessibilityHidden(true)
    }
}

private struct ShareVictoryRunner: View {
    let runner: ShareVictory.Runner
    let format: ShareFormat

    var body: some View {
        HStack(spacing: .spaceS) {
            if format.victoryShowsRunnerPortrait {
                PersonPortrait(
                    slug: runner.face.slug, name: runner.face.name, party: runner.face.party,
                    size: .sharePortraitSmall)
            }
            Text(verbatim: runner.face.name)
                .font(format.victoryRunnerName)
                .lineLimit(1)
                .minimumScaleFactor(.shareTextShrink)
            ShareVictoryParty(party: runner.face.party, size: .posterVictoryPartySmall)
            Spacer(minLength: .spaceS)
            ShareFigure(value: runner.percent, size: format.factSize)
                .fixedSize()
        }
        .padding(.horizontal, .spaceS)
        .padding(.vertical, .spaceXS)
        .background(.white.opacity(.opacityTint), in: .rect(cornerRadius: .radiusM))
        .opacity(.opacityStrong)
    }
}

private struct ShareVictoryBallots: View {
    let ballots: [ShareVictory.Ballot]

    var body: some View {
        if !ballots.isEmpty {
            VStack(alignment: .leading, spacing: .spaceXS) {
                TallyBar(
                    segments: ballots.map {
                        TallyBar.Segment(
                            id: $0.id, value: $0.share, color: .white.opacity(Self.opacity($0.kind))
                        )
                    }, height: .posterVictoryLine)
                HStack(spacing: .spaceM) {
                    ForEach(ballots) { ballot in
                        HStack(spacing: .space2XS) {
                            Circle()
                                .fill(.white.opacity(Self.opacity(ballot.kind)))
                                .frame(width: .spaceXS, height: .spaceXS)
                            Text(verbatim: ballot.title)
                                .foregroundStyle(Color.posterSecondary)
                            Text(verbatim: ballot.percent)
                                .fontWeight(.heavy)
                                .monospacedDigit()
                        }
                        .lineLimit(1)
                    }
                }
                .font(.posterLabel)
            }
        }
    }

    static func opacity(_ kind: ShareVictory.Ballot.Kind) -> Double {
        switch kind {
        case .valid: 1
        case .blank: .opacityStrong - .opacityTint
        case .null: .opacitySoft
        }
    }
}

private struct ShareVictoryFooter: View {
    let card: ShareCard
    let context: String
    let code: CGImage?

    var body: some View {
        HStack(alignment: .bottom, spacing: .spaceM) {
            VStack(alignment: .leading, spacing: .space2XS) {
                Text(verbatim: context)
                    .font(.posterSource)
                    .foregroundStyle(Color.posterSecondary)
                    .lineLimit(2)
                    .minimumScaleFactor(.shareTextShrink)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(alignment: .firstTextBaseline, spacing: .spaceXS) {
                    Text(verbatim: card.brand)
                        .font(.posterBrand)
                    Text(verbatim: ShareCardBuilder.host)
                        .font(.posterHost)
                        .foregroundStyle(Color.posterSecondary)
                }
                .lineLimit(1)
            }
            Spacer(minLength: .zero)
            if let code, card.format.showsCode {
                Image(decorative: code, scale: 1)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: .posterCode, height: .posterCode)
                    .padding(.posterCodeInset)
                    .background(.white, in: .rect(cornerRadius: .space2XS))
            }
        }
    }
}
