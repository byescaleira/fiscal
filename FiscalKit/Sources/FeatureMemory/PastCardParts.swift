import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct PartyCardBackground: View {
    let party: String

    var body: some View {
        let palette = PartyPalette.of(party: party, fallback: 0)
        ZStack {
            LinearGradient(
                colors: [palette.primary, palette.secondary], startPoint: .topLeading,
                endPoint: .bottomTrailing)
            Color.scoreboard.opacity(.opacitySoft)
        }
    }
}

struct PastOtherRow: View {
    let name: String
    let party: String
    let share: String
    var portraitSlug: String?

    var body: some View {
        HStack(spacing: .spaceS) {
            if let portraitSlug {
                PersonPortrait(slug: portraitSlug, name: name, party: party, size: .badgeM)
            }
            Text(verbatim: name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Text(verbatim: party)
                .font(.caption.weight(.bold))
            Spacer(minLength: .spaceS)
            Text(verbatim: share)
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
        }
        .padding(.spaceS)
        .background(.white.opacity(.opacityTint), in: .rect(cornerRadius: .radiusM))
        .opacity(.opacityStrong)
    }
}
