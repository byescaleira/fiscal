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
            LensLookPreview(palette: setup.palette, theme: setup.draft.themes.first)
            LensLookCard(
                "Palette",
                detail: "Mirrored pairs side by side. Never taken from the color of a party."
            ) {
                LensPaletteGrid(
                    swatches: setup.paletteGrid, selected: setup.palette,
                    suggested: setup.suggestedPalette
                ) { setup.choose($0) }
            }
            LensSetupArtCard()
            if setup.supportsIcons {
                LensLookShelf(
                    "App Icon", detail: "One icon for each palette, or the Amazon at dawn."
                ) {
                    LensIconStrip(
                        placement: .padded(.spaceInset), icons: setup.iconChoices,
                        selected: setup.appIcon,
                        suggested: setup.suggestedIcon
                    ) { icon in
                        Task { await setup.choose(icon) }
                    }
                }
            }
        }
    }
}

private struct LensSetupArtCard: View {
    @Environment(LensSetupModel.self) private var setup
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.liteMode) private var liteMode

    var body: some View {
        LensLookShelf(
            "Art", detail: "Works by Brazilian artists in the public domain or under a free licence, always with credit."
        ) {
            if setup.collections.count > 1 {
                LensCollectionPicker(
                    placement: .padded(.spaceInset), collections: setup.collections,
                    isChosen: setup.isChosen(_:), count: { setup.works(in: $0).count }
                ) { setup.choose($0) }
            }
            LensArtCarousel(placement: .padded(.spaceInset), works: setup.collectionWorks)
                .id(setup.collection?.id)
                .transition(.opacity)
        }
        .animation(
            systemReduceMotion || liteMode.reducesMotion ? nil : .smooth,
            value: setup.collection?.id)
    }
}

struct LensLookCard<Content: View>: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let content: Content

    init(
        _ title: LocalizedStringKey, detail: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.detail = detail
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceM) {
            LensChoiceTitle(title, detail: detail)
            content
        }
        .padding(.spaceL)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(.opacityFill))
        .clipShape(.rect(cornerRadius: .radiusGroup))
    }
}

private struct LensLookShelf<Content: View>: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let content: Content

    init(
        _ title: LocalizedStringKey, detail: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.detail = detail
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceM) {
            LensChoiceTitle(title, detail: detail)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
            Text(title).sectionTitle().accessibilityAddTraits(.isHeader)
            Text(detail).font(.footnote).foregroundStyle(.secondary)
        }
    }
}
