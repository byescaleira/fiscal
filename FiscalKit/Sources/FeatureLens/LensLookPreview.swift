import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct LensLookPreview: View {
    @Environment(\.appTint) private var inheritedTint
    let palette: LensPaletteSwatch?
    let theme: Theme?

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceM) {
            HStack(spacing: .spaceS) {
                Text("Preview")
                    .font(.chipLabel)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                Spacer(minLength: .zero)
                LensBadge()
            }
            LensPreviewVoteCard(theme: theme ?? .health)
            LensPreviewControls()
        }
        .padding(.spaceL)
        .background(.groupedBackground, in: .rect(cornerRadius: .radiusGroup))
        .appTint(palette?.accent ?? inheritedTint)
        .partyMarksStill()
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
        .animation(.smooth, value: palette)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Preview of your look"))
        .accessibilityValue(Text(verbatim: palette?.title ?? ""))
    }
}

private struct LensPreviewVoteCard: View {
    @Environment(\.appTint) private var tint
    let theme: Theme

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceS) {
            HStack(spacing: .spaceS) {
                Label {
                    Text(verbatim: theme.title.uppercased())
                } icon: {
                    Image(systemName: theme.symbol)
                }
                .font(.caption2.weight(.heavy))
                .foregroundStyle(tint)
                .lineLimit(1)
                Spacer(minLength: .zero)
                Label("By your lens", systemImage: "eyeglasses")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(tint)
                    .lineLimit(1)
            }
            Text(verbatim: LensText.sampleHeadline(theme))
                .font(.headline)
                .lineLimit(2)
            HStack(alignment: .lastTextBaseline, spacing: .spaceL) {
                LensPreviewCount(label: "Yes", value: 312, symbol: "checkmark", color: .positive)
                LensPreviewCount(label: "No", value: 141, symbol: "xmark", color: .negative)
                Spacer(minLength: .zero)
                Label("Approved", systemImage: "checkmark.seal")
                    .font(.chipLabel)
                    .foregroundStyle(Color.positive)
                    .padding(.horizontal, .spaceS)
                    .padding(.vertical, .space2XS)
                    .background(Color.positive.opacity(.opacityTint), in: .capsule)
            }
            TallyBar(segments: [
                TallyBar.Segment(id: "yes", value: 312, color: .positive),
                TallyBar.Segment(id: "no", value: 141, color: .negative),
                TallyBar.Segment(id: "others", value: 12, color: .warning),
            ])
            HStack(spacing: .spaceXS) {
                ForEach(LensText.sampleParties, id: \.self) { party in
                    PartyMark(party)
                }
                Spacer(minLength: .zero)
                Text("Party colors never change")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(.spaceL)
        .background(.groupedRow, in: .rect(cornerRadius: .radiusL))
    }
}

private struct LensPreviewCount: View {
    let label: LocalizedStringKey
    let value: Int
    let symbol: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceHairline) {
            Label(label, systemImage: symbol)
                .font(.caption2.weight(.heavy))
                .textCase(.uppercase)
                .foregroundStyle(color)
            Text(verbatim: PublicFormat.number(value))
                .font(.scoreboardNumber)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }
}

private struct LensPreviewControls: View {
    @Environment(\.appTint) private var tint

    var body: some View {
        HStack(spacing: .spaceM) {
            Label("Follow", systemImage: "plus")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, .spaceL)
                .padding(.vertical, .spaceS)
                .background(tint, in: .capsule)
            Spacer(minLength: .zero)
            HStack(spacing: .spaceM) {
                ForEach(AppSection.allCases) { section in
                    Image(systemName: section.systemImage)
                        .foregroundStyle(section == .today ? tint : Color.secondary)
                }
            }
            .font(.icon(.s))
            .padding(.horizontal, .spaceM)
            .padding(.vertical, .spaceS)
            .background(.groupedRow, in: .capsule)
        }
    }
}
