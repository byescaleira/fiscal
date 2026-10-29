import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct PastWinnerCard: View {
    let year: Int
    let caption: String
    let winner: PastPick
    let runnerUp: PastPick?
    let footnote: String?

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceM) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: String(year))
                    .font(.scoreboardTitle)
                    .monospacedDigit()
                    .amountLine()
                Spacer(minLength: .spaceS)
                StatusCircle(
                    String(appLocalized: "Elected"), symbol: "checkmark.seal.fill", color: .white)
            }
            PastWinnerHeadline(winner: winner)
            if let runnerUp {
                PastOtherRow(
                    name: runnerUp.displayName, party: runnerUp.party, share: runnerUp.shareText)
            }
            Text(verbatim: caption)
                .font(.caption.weight(.medium))
                .opacity(.opacityStrong)
            if let footnote {
                Text(verbatim: footnote)
                    .font(.caption2.weight(.medium))
                    .opacity(.opacityStrong)
            }
        }
        .padding(.spaceL)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { PartyCardBackground(party: winner.party) }
        .clipShape(.rect(cornerRadius: .radiusGroup))
        .accessibilityElement(children: .combine)
    }
}

private struct PastWinnerHeadline: View {
    let winner: PastPick

    var body: some View {
        HStack(spacing: .spaceM) {
            PersonPortrait(
                slug: winner.portraitSlug, name: winner.displayName, party: winner.party,
                size: .badgeXL
            )
            .overlay { Circle().strokeBorder(.white, lineWidth: .spaceHairline) }
            VStack(alignment: .leading, spacing: .space2XS) {
                Text(verbatim: winner.displayName)
                    .font(.emphasis(.title3, weight: .heavy))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                HStack(spacing: .spaceS) {
                    PartyMark(winner.party)
                    Text(verbatim: winner.shareText)
                        .font(.emphasis(.headline, weight: .bold))
                        .monospacedDigit()
                }
            }
        }
    }
}
