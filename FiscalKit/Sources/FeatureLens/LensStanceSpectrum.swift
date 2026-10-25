import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct LensSpectrumCard: View {
    @Environment(LensSetupModel.self) private var setup
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceL) {
            VStack(alignment: .leading, spacing: .space2XS) {
                Text("From left to right")
                    .font(.chipLabel)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                Group {
                    if let pick = setup.spectrumPick {
                        Text(verbatim: pick.title).foregroundStyle(.primary)
                    } else {
                        Text("Tap a point on the line").foregroundStyle(.secondary)
                    }
                }
                .font(.title2.weight(.bold))
                .contentTransition(.opacity)
            }
            .accessibilityHidden(true)
            if typeSize.isAccessibilitySize {
                LensSpectrumList()
            } else {
                LensSpectrumLine()
            }
        }
        .padding(.spaceL)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(.opacityFill), in: .rect(cornerRadius: .radiusGroup))
        .animation(.smooth, value: setup.spectrumPick)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Left to right scale"))
    }
}

private struct LensSpectrumLine: View {
    @Environment(LensSetupModel.self) private var setup

    var body: some View {
        let stops = setup.spectrumChoices
        HStack(alignment: .top, spacing: .zero) {
            ForEach(stops) { stance in
                LensSpectrumStop(stance: stance)
            }
        }
        .background(alignment: .top) {
            GeometryReader { proxy in
                let inset = proxy.size.width / CGFloat(max(stops.count, 1)) / 2
                Capsule()
                    .fill(Color.primary.opacity(.opacityTint))
                    .frame(height: .spectrumTrack)
                    .padding(.horizontal, inset)
                    .frame(height: .badgeS)
            }
            .accessibilityHidden(true)
        }
    }
}

private struct LensSpectrumStop: View {
    @Environment(LensSetupModel.self) private var setup
    @Environment(\.appTint) private var tint
    let stance: PoliticalStance

    var body: some View {
        let isSelected = setup.isChosen(stance)
        Button {
            setup.choose(stance)
        } label: {
            VStack(spacing: .spaceS) {
                LensSpectrumKnob(isSelected: isSelected, tint: tint)
                Text(verbatim: stance.title)
                    .font(.caption.weight(isSelected ? .bold : .semibold))
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: stance.title))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

private struct LensSpectrumKnob: View {
    let isSelected: Bool
    let tint: Color

    var body: some View {
        ZStack {
            if isSelected {
                Circle()
                    .fill(tint)
                    .overlay { Circle().strokeBorder(.white, lineWidth: .selectionStroke) }
                    .frame(width: .badgeS, height: .badgeS)
                    .overlay {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                    }
                    .transition(.scale.combined(with: .opacity))
            } else {
                Circle()
                    .fill(Color.primary.opacity(.opacityStrong))
                    .frame(width: .spectrumDot, height: .spectrumDot)
            }
        }
        .frame(height: .badgeS)
        .accessibilityHidden(true)
    }
}

private struct LensSpectrumList: View {
    @Environment(LensSetupModel.self) private var setup

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceS) {
            ForEach(setup.spectrumChoices) { stance in
                let isSelected = setup.isChosen(stance)
                Button {
                    setup.choose(stance)
                } label: {
                    HStack(spacing: .spaceM) {
                        SelectionMark(isSelected: isSelected)
                        Text(verbatim: stance.title)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)
                        Spacer(minLength: .zero)
                    }
                    .padding(.vertical, .spaceXS)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
    }
}

struct LensNeutralChoices: View {
    @Environment(LensSetupModel.self) private var setup
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout =
            typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: .spaceM))
            : AnyLayout(HStackLayout(alignment: .top, spacing: .spaceM))
        VStack(alignment: .leading, spacing: .spaceS) {
            Text("Without picking a side, just as valid")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            layout {
                ForEach(setup.neutralChoices) { stance in
                    LensNeutralCard(stance: stance)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct LensNeutralCard: View {
    @Environment(LensSetupModel.self) private var setup
    @Environment(\.appTint) private var tint
    let stance: PoliticalStance

    var body: some View {
        let isSelected = setup.isChosen(stance)
        Button {
            setup.choose(stance)
        } label: {
            VStack(alignment: .leading, spacing: .spaceS) {
                HStack(alignment: .top) {
                    Image(systemName: stance.choiceSymbol)
                        .font(.icon(.m, weight: .semibold))
                        .foregroundStyle(tint)
                        .frame(width: .badgeL, height: .badgeL)
                        .background(tint.opacity(.opacityTint), in: .circle)
                    Spacer(minLength: .zero)
                    SelectionMark(isSelected: isSelected)
                }
                Text(verbatim: stance.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(verbatim: stance.choiceDetail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.spaceL)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .contentShape(.rect(cornerRadius: .radiusL))
        }
        .buttonStyle(.plain)
        .lensChoice(isSelected: isSelected)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: stance.title))
        .accessibilityHint(Text(verbatim: stance.choiceDetail))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

struct LensEffectCard: View {
    @Environment(LensSetupModel.self) private var setup

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceM) {
            Text("What changes in Fiscal")
                .font(.chipLabel)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            if let title = setup.effectTitle {
                LensEffectDetails(title: title)
            } else {
                Label("Choose an option to see what comes first for you.", systemImage: "eye")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Divider()
            Label(
                "Never changes: the numbers, the votes, the spending and the sources.",
                systemImage: "checkmark.shield"
            )
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
        }
        .padding(.spaceL)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(.opacityFill), in: .rect(cornerRadius: .radiusGroup))
        .animation(.smooth, value: setup.draft)
        .accessibilityElement(children: .combine)
    }
}

private struct LensEffectDetails: View {
    @Environment(LensSetupModel.self) private var setup
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceM) {
            VStack(alignment: .leading, spacing: .space2XS) {
                Text(verbatim: title).font(.headline)
                if let first = setup.firstThemesText {
                    Text(verbatim: first)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            FlowLayout(spacing: .spaceS) {
                ForEach(setup.draft.themes) { theme in
                    LensThemeChip(theme: theme)
                }
            }
            HStack(spacing: .spaceM) {
                if let work = setup.backdrop {
                    ArtPoster(work: work, width: .artThumb, height: .artThumb, showsCredit: false)
                }
                VStack(alignment: .leading, spacing: .space2XS) {
                    if let palette = setup.palette {
                        HStack(spacing: .spaceS) {
                            LensSwatch(swatch: palette)
                            Text(verbatim: palette.title).font(.subheadline.weight(.semibold))
                        }
                    }
                    if let work = setup.backdrop {
                        Text(verbatim: "\(work.artist) · \(work.caption)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            }
            if let detail = setup.effectDetail {
                Text(verbatim: detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
