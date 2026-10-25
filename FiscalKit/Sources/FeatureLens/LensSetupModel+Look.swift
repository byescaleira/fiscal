import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import FiscalResource
import Foundation

extension LensSetupModel {
    public var spectrumChoices: [PoliticalStance] { PoliticalStance.spectrum }

    public var neutralChoices: [PoliticalStance] { PoliticalStance.neutral }

    public var spectrumPick: PoliticalStance? {
        draft.stance.flatMap { $0.isOnSpectrum ? $0 : nil }
    }

    public var effectTitle: String? {
        draft.stance.map(LensText.choiceTitle(for:))
    }

    public var effectDetail: String? {
        draft.stance.map(LensText.effect(for:))
    }

    public var firstThemesText: String? { LensText.firstThemes(draft.themes) }

    public var paletteGrid: [LensPaletteSwatch] { LensPaletteSwatch.grid }

    public var suggestedPalette: LensPaletteSwatch? {
        draft.stance.flatMap { LensPaletteSwatch.named(LensPreset.suggested(for: $0).palette) }
    }

    public var collectionWorks: [ArtWork] {
        collection.map(works(in:)) ?? []
    }

    public var iconChoices: [AppIcon] { LensIcons.choices(suggested: suggestedIcon) }

    public var suggestedIcon: AppIcon? { palette?.appIcon }
}
