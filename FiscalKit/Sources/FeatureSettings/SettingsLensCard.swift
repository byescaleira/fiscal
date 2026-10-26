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
                    Text(verbatim: summary.title)
                        .font(.titleMedium)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    LensCardDetails(summary: summary)
                }
                Spacer(minLength: .zero)
            }
            if !summary.cards.isEmpty {
                LensFaces(cards: summary.cards, size: .badgeL)
            } else if summary.prefersNotToSay {
                Label("Neutral, without supporting anyone", systemImage: "hand.raised")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
            } else {
                Text("Choose who you support, your topics and your look. It takes about a minute.")
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
                    Image(systemName: "heart")
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
