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
        let palette = PartyPalette.of(party: winner.party, fallback: 0)
        VStack(alignment: .leading, spacing: .spaceM) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: String(year))
                    .font(.scoreboardTitle)
                    .monospacedDigit()
                Spacer(minLength: .spaceS)
                StatusCircle(
                    String(appLocalized: "Elected"), symbol: "checkmark.seal.fill", color: .white)
            }
            HStack(spacing: .spaceM) {
                PersonPortrait(
                    slug: winner.portraitSlug,
                    name: winner.displayName,
                    party: winner.party, size: .badgeXL
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
            if let runnerUp {
                HStack(spacing: .spaceS) {
                    Text(verbatim: runnerUp.displayName)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(verbatim: runnerUp.party)
                        .font(.caption.weight(.bold))
                        .opacity(.opacityStrong)
                    Spacer(minLength: .spaceS)
                    Text(verbatim: runnerUp.shareText)
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                }
                .padding(.spaceS)
                .background(.white.opacity(.opacityTint), in: .rect(cornerRadius: .radiusM))
                .opacity(.opacityStrong)
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
        .background {
            ZStack {
                LinearGradient(
                    colors: [palette.primary, palette.secondary], startPoint: .topLeading,
                    endPoint: .bottomTrailing)
                Color.scoreboard.opacity(.opacitySoft)
            }
        }
        .clipShape(.rect(cornerRadius: .radiusGroup))
        .accessibilityElement(children: .combine)
    }
}
