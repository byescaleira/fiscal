import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct RaceHeroHeader: View {
    @ReducesMotion private var reduceMotion
    @Environment(\.open) private var open
    @Environment(\.navigationSection) private var section
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let summary: RaceSummary

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: .spaceS) {
                HStack(alignment: .center, spacing: .spaceS) {
                    statusCircle
                    Spacer(minLength: .spaceS)
                    actions
                }
                kicker
                title
            }
        } else {
            HStack(alignment: .center, spacing: .spaceS) {
                HStack(spacing: .spaceXS) {
                    statusCircle
                    kicker
                }
                title
                Spacer(minLength: .spaceS)
                actions
            }
        }
    }

    private var statusCircle: some View {
        StatusCircle(summary.statusText, symbol: summary.statusSymbol, color: .white)
            .symbolEffect(
                .pulse,
                isActive: !reduceMotion && !MotionBudget.isConstrained && summary.isCounting
            )
            .accessibilityHidden(true)
    }

    private var kicker: some View {
        Text(verbatim: summary.statusKicker)
            .font(.chipLabel)
            .lineLimit(1)
            .fixedSize()
            .accessibilityLabel(Text(verbatim: summary.statusText))
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: summary.title)
                .font(.subheadline.weight(.bold))
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)
            Text(verbatim: summary.roundText)
                .font(.caption.weight(.medium))
                .opacity(.opacityStrong)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var actions: some View {
        Button("Share", systemImage: "square.and.arrow.up") {
            open(.share(.race(id: summary.race.id)), in: section)
        }
        .labelStyle(.iconOnly)
        .font(.body.weight(.semibold))
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .buttonStyle(.plain)
        .frame(width: .badgeL, height: .badgeL)
        .background(.white.opacity(.opacityTint), in: .circle)
    }
}
