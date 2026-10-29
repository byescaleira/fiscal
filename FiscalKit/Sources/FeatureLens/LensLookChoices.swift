import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import FiscalResource
import SwiftUI

struct LensPaletteGrid: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let swatches: [LensPaletteSwatch]
    let selected: LensPaletteSwatch?
    let suggested: LensPaletteSwatch?
    let choose: (LensPaletteSwatch) -> Void

    var body: some View {
        let count = typeSize.isAccessibilitySize ? 1 : 2
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: .spaceM), count: count),
            spacing: .spaceM
        ) {
            ForEach(swatches) { swatch in
                LensPaletteTile(
                    swatch: swatch, isSelected: swatch == selected,
                    isSuggested: swatch == suggested
                ) {
                    choose(swatch)
                }
            }
        }
        .sensoryFeedback(.selection, trigger: selected)
    }
}

private struct LensPaletteTile: View {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.liteMode) private var liteMode
    let swatch: LensPaletteSwatch
    let isSelected: Bool
    let isSuggested: Bool
    let action: () -> Void

    var body: some View {
        let reduceMotion = systemReduceMotion || liteMode.reducesMotion
        Button(action: action) {
            VStack(alignment: .leading, spacing: .zero) {
                swatch.gradient
                    .frame(height: .lensSwatchHeight)
                    .overlay(alignment: .topTrailing) {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.icon(.m, weight: .semibold))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(swatch.accent, .white)
                                .padding(.spaceS)
                                .transition(
                                    reduceMotion ? .opacity : .scale.combined(with: .opacity))
                        }
                    }
                VStack(alignment: .leading, spacing: .space2XS) {
                    Text(verbatim: swatch.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    if isSuggested {
                        Text("Suggested to start")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(swatch.accent)
                    } else {
                        Text(verbatim: swatch.pairText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.spaceM)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.primary.opacity(.opacityFill))
            .clipShape(.rect(cornerRadius: .radiusL))
            .overlay {
                RoundedRectangle(cornerRadius: .radiusL)
                    .strokeBorder(isSelected ? swatch.accent : .clear, lineWidth: .selectionStroke)
            }
            .contentShape(.rect(cornerRadius: .radiusL))
        }
        .buttonStyle(.plain)
        .animation(reduceMotion ? nil : .smooth, value: isSelected)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: swatch.title))
        .accessibilityValue(Text(verbatim: swatch.pairText))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

struct LensCollectionPicker: View {
    var placement: RailPlacement = .listRow
    let collections: [ArtCollection]
    let isChosen: (ArtCollection) -> Bool
    let count: (ArtCollection) -> Int
    let choose: (ArtCollection) -> Void

    var body: some View {
        EdgeToEdgeRail(placement, spacing: .spaceS, snaps: false) {
            ForEach(collections) { collection in
                LensCollectionButton(
                    collection: collection, count: count(collection),
                    isSelected: isChosen(collection)
                ) {
                    choose(collection)
                }
            }
        }
    }
}

private struct LensCollectionButton: View {
    @Environment(\.appTint) private var tint
    let collection: ArtCollection
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: .spaceXS) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .accessibilityHidden(true)
                }
                Text(verbatim: collection.name)
                Text(verbatim: PublicFormat.number(count))
                    .foregroundStyle(isSelected ? tint : Color.secondary)
                    .monospacedDigit()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isSelected ? tint : Color.primary)
            .padding(.horizontal, .spaceM)
            .padding(.vertical, .spaceS)
            .background(
                isSelected ? tint.opacity(.opacityTint) : Color.primary.opacity(.opacityFill),
                in: .capsule
            )
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: collection.name))
        .accessibilityValue(Text("\(count) works"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct LensArtCarousel: View {
    var placement: RailPlacement = .listRow
    let works: [ArtWork]

    var body: some View {
        EdgeToEdgeRail(placement, lazy: true) {
            ForEach(works) { work in
                ArtPoster(work: work, width: .lensArtCardWidth, height: .lensArtCardHeight)
            }
        }
    }
}

struct LensIconStrip: View {
    var placement: RailPlacement = .listRow
    let icons: [AppIcon]
    let selected: AppIcon
    let suggested: AppIcon?
    let choose: (AppIcon) -> Void

    var body: some View {
        EdgeToEdgeRail(placement, spacing: .spaceL, snaps: false) {
            ForEach(icons) { icon in
                LensIconButton(
                    icon: icon, isSelected: icon == selected, isSuggested: icon == suggested
                ) {
                    choose(icon)
                }
            }
        }
        .sensoryFeedback(.selection, trigger: selected)
    }
}

private struct LensIconButton: View {
    @Environment(\.appTint) private var tint
    let icon: AppIcon
    let isSelected: Bool
    let isSuggested: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: .spaceXS) {
                AppIconImage(icon: icon, size: .badgeXL)
                    .padding(.space2XS)
                    .overlay {
                        RoundedRectangle(cornerRadius: .radiusM, style: .continuous)
                            .strokeBorder(isSelected ? tint : .clear, lineWidth: .selectionStroke)
                    }
                Text(verbatim: icon.title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isSelected ? tint : Color.primary)
                    .lineLimit(1)
                if isSuggested {
                    Text("Suggested")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: .badgeXL + .spaceL)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: icon.title))
        .accessibilityValue(isSuggested ? Text("Suggested") : Text(verbatim: ""))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
