import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import FiscalResource
import SwiftUI

struct SettingsLensCard: View {
    @Environment(\.appTint) private var inheritedTint
    let summary: LensSummary

    var body: some View {
        let tint = summary.palette?.accent ?? inheritedTint
        VStack(alignment: .leading, spacing: .spaceL) {
            HStack(alignment: .top, spacing: .spaceL) {
                LensArtThumb(summary: summary)
                VStack(alignment: .leading, spacing: .space2XS) {
                    Text("Your Fiscal")
                        .font(.chipLabel)
                        .textCase(.uppercase)
                        .foregroundStyle(tint)
                    Text(verbatim: summary.stanceTitle)
                        .font(.titleMedium)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    LensCardDetails(summary: summary)
                }
                Spacer(minLength: .zero)
            }
            if summary.isOnSpectrum, let stance = summary.stance {
                LensMiniRuler(stance: stance)
            } else if summary.isSet {
                Label("Without picking a side", systemImage: "scale.3d")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
            } else {
                Text("Choose your themes, your side and your look. It takes about a minute.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            LensCardFooter(summary: summary)
        }
        .padding(.vertical, .spaceS)
        .appTint(tint)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Opens your Lens"))
    }
}

private struct LensArtThumb: View {
    @Environment(\.appTint) private var tint
    let summary: LensSummary

    var body: some View {
        Group {
            if let work = summary.work {
                Color.clear.overlay { work.image.resizable().scaledToFill() }
            } else {
                ZStack {
                    if let palette = summary.palette {
                        Rectangle().fill(palette.gradient)
                    } else {
                        tint.opacity(.opacityTint)
                    }
                    Image(systemName: "eyeglasses")
                        .font(.icon(.l, weight: .semibold))
                        .foregroundStyle(summary.palette == nil ? tint : .white)
                }
            }
        }
        .frame(width: .artThumb, height: .lensCardArtHeight)
        .clipShape(.rect(cornerRadius: .radiusM, style: .continuous))
        .overlay(alignment: .bottomTrailing) {
            if let palette = summary.palette, summary.work != nil {
                Circle()
                    .fill(palette.gradient)
                    .overlay { Circle().strokeBorder(.white, lineWidth: .selectionStroke) }
                    .frame(width: .badgeS, height: .badgeS)
                    .offset(x: .spaceS, y: .spaceS)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct LensCardDetails: View {
    let summary: LensSummary

    var body: some View {
        VStack(alignment: .leading, spacing: .space2XS) {
            if let palette = summary.palette, let title = summary.paletteTitle {
                HStack(spacing: .spaceXS) {
                    Circle()
                        .fill(palette.gradient)
                        .frame(width: .spectrumDot, height: .spectrumDot)
                    Text(verbatim: title)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            }
            if let themes = summary.themesText {
                Text(verbatim: themes)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }
}

private struct LensMiniRuler: View {
    @Environment(\.appTint) private var tint
    let stance: PoliticalStance

    var body: some View {
        VStack(spacing: .spaceXS) {
            HStack(spacing: .zero) {
                ForEach(LensSummary.spectrum) { stop in
                    ZStack {
                        if stop == stance {
                            Circle()
                                .fill(tint)
                                .overlay {
                                    Circle().strokeBorder(.white, lineWidth: .selectionStroke)
                                }
                                .frame(width: .badgeS, height: .badgeS)
                        } else {
                            Circle()
                                .fill(Color.primary.opacity(.opacitySoft))
                                .frame(width: .spectrumDot, height: .spectrumDot)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: .badgeS)
                }
            }
            .background {
                Capsule()
                    .fill(Color.primary.opacity(.opacityTint))
                    .frame(height: .spectrumTrack)
                    .padding(.horizontal, .spaceL)
            }
            HStack {
                Text(verbatim: PoliticalStance.left.title)
                Spacer()
                Text(verbatim: PoliticalStance.right.title)
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
        }
        .accessibilityHidden(true)
    }
}

private struct LensCardFooter: View {
    let summary: LensSummary

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: .spaceS) {
                privacy
                Spacer(minLength: .spaceS)
                credit
            }
            VStack(alignment: .leading, spacing: .space2XS) {
                privacy
                credit
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var privacy: some View {
        Label("Only on this device", systemImage: "lock")
            .labelStyle(.titleAndIcon)
            .lineLimit(1)
    }

    @ViewBuilder private var credit: some View {
        if let credit = summary.credit {
            Text(verbatim: credit).lineLimit(1)
        }
    }
}
