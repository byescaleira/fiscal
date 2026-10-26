import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import FiscalResource
import Foundation

extension LensSetupModel {
    public var paletteGrid: [LensPaletteSwatch] { LensPaletteSwatch.grid }

    public var suggestedPalette: LensPaletteSwatch? {
        LensPaletteSwatch.named(Lens.suggestedPalette)
    }

    public var collectionWorks: [ArtWork] {
        collection.map(works(in:)) ?? []
    }

    public var iconChoices: [AppIcon] { LensIcons.choices(suggested: suggestedIcon) }

    public var suggestedIcon: AppIcon? { palette?.appIcon }
}
