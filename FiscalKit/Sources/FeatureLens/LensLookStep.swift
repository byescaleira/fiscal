import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import FiscalResource
import SwiftUI

struct LensLookStep: View {
    @Environment(LensSetupModel.self) private var setup

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceXL) {
            LensStepHeader(
                "Your look",
                message: Text(
                    "Colors and art for the app and your cards. Charts, scoreboards and politicians keep their own colors."
                ))
            LookPreview()
            PaletteChoices()
            CollectionChoices()
        }
    }
}

private struct LookPreview: View {
    @Environment(LensSetupModel.self) private var setup
    @Environment(\.appTint) private var tint

    var body: some View {
        HStack(spacing: .spaceM) {
            if let work = setup.backdrop {
                ArtPoster(work: work, width: .artThumb, height: .artThumb, showsCredit: false)
            }
            VStack(alignment: .leading, spacing: .spaceS) {
                if let stance = setup.draft.stance {
                    LensBadge(stance)
                }
                HStack(spacing: .spaceXS) {
                    ForEach(setup.draft.themes.prefix(2)) { theme in
                        Chip(theme.title, color: tint)
                    }
                }
            }
            Spacer(minLength: .zero)
        }
        .padding(.spaceM)
        .background {
            if let palette = setup.palette {
                palette.gradient.opacity(.opacitySoft)
            }
        }
        .background(Color.primary.opacity(.opacityFill))
        .clipShape(.rect(cornerRadius: .radiusL))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Preview of your look"))
    }
}

private struct PaletteChoices: View {
    @Environment(LensSetupModel.self) private var setup

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceM) {
            LensChoiceTitle("Palette", detail: "Mirrored pairs. Any palette fits any side.")
            ForEach(setup.palettePairs, id: \.self) { pair in
                AdaptiveStack(spacing: .spaceM) {
                    ForEach(pair) { swatch in
                        PaletteButton(swatch: swatch)
                    }
                }
            }
        }
    }
}

private struct PaletteButton: View {
    @Environment(LensSetupModel.self) private var setup
    let swatch: LensPaletteSwatch

    var body: some View {
        let isSelected = setup.isChosen(swatch)
        Button {
            setup.choose(swatch)
        } label: {
            HStack(spacing: .spaceS) {
                LensSwatch(swatch: swatch)
                Text(verbatim: swatch.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer(minLength: .zero)
                SelectionMark(isSelected: isSelected)
            }
            .padding(.spaceS)
            .frame(maxWidth: .infinity)
            .contentShape(.rect(cornerRadius: .radiusL))
        }
        .buttonStyle(.plain)
        .lensChoice(isSelected: isSelected)
        .accessibilityLabel(Text(verbatim: swatch.title))
        .accessibilityValue(Text(verbatim: swatch.pairText))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct CollectionChoices: View {
    @Environment(LensSetupModel.self) private var setup

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceM) {
            LensChoiceTitle(
                "Art", detail: "Public domain works from Brazilian artists, always with credit.")
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: .posterHeight), spacing: .spaceM)],
                spacing: .spaceM
            ) {
                ForEach(setup.collections) { collection in
                    CollectionCard(collection: collection)
                }
            }
        }
    }
}

private struct CollectionCard: View {
    @Environment(LensSetupModel.self) private var setup
    let collection: ArtCollection

    var body: some View {
        let isSelected = setup.isChosen(collection)
        let works = setup.works(in: collection)
        Button {
            setup.choose(collection)
        } label: {
            VStack(alignment: .leading, spacing: .spaceS) {
                if let lead = works.first {
                    ArtPoster(work: lead, width: nil, height: .posterWidth)
                }
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: .space2XS) {
                        Text(verbatim: collection.name).font(.headline)
                        Text("\(works.count) works")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: .zero)
                    SelectionMark(isSelected: isSelected)
                }
                .padding(.horizontal, .spaceS)
                .padding(.bottom, .spaceS)
            }
            .padding(.spaceXS)
            .contentShape(.rect(cornerRadius: .radiusL))
        }
        .buttonStyle(.plain)
        .lensChoice(isSelected: isSelected)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct LensChoiceTitle: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    init(_ title: LocalizedStringKey, detail: LocalizedStringKey) {
        self.title = title
        self.detail = detail
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .space2XS) {
            Text(title).font(.title3.weight(.bold)).accessibilityAddTraits(.isHeader)
            Text(detail).font(.footnote).foregroundStyle(.secondary)
        }
    }
}
