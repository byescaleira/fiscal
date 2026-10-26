import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import FiscalResource
import Foundation

extension LensModel {
    public static let focusLimit = 5

    public var tally: LensThemeTally? {
        guard let recentVotes, !recentVotes.isEmpty else { return nil }
        return LensThemeTally(votes: recentVotes, themes: themes)
    }

    public var showsChart: Bool { tally?.touchesThemes == true }

    public var focusedSlice: LensThemeTally.Slice? {
        focusedTheme.flatMap { tally?.slice(of: $0) }
    }

    public var focusedVotes: [VoteSummary] {
        Array((focusedSlice?.votes ?? []).prefix(Self.focusLimit))
    }

    public func focus(_ theme: Theme) {
        focusedTheme = focusedTheme == theme ? nil : theme
    }

    public func countText(_ count: Int) -> String {
        String(appLocalized: "Votes: \(count)")
    }

    public func approvedText(for slice: LensThemeTally.Slice) -> String? {
        guard slice.approved > 0, slice.approved < slice.count else { return nil }
        return String(appLocalized: "Approved: \(slice.approved)")
    }

    public func accessibilityValue(for slice: LensThemeTally.Slice) -> String {
        String(
            appLocalized:
                "Votes: \(slice.count), approved: \(slice.approved), rejected: \(slice.rejected)")
    }

    public func focusTitle(for slice: LensThemeTally.Slice) -> String {
        String(appLocalized: "Latest votes on \(slice.theme.title)")
    }

    public func rankText(_ index: Int) -> String {
        PublicFormat.number(index + 1)
    }

    public func moveThemes(from source: IndexSet, to destination: Int) async {
        await update { $0.moveTheme(from: source, to: destination) }
    }

    public func moveTheme(_ theme: Theme, by offset: Int) async {
        await update { $0.moveTheme(theme, by: offset) }
    }

    public func removeTheme(_ theme: Theme) async {
        guard lens?.canRemoveTheme == true else { return }
        await update { $0.toggle(theme) }
    }

    public var collections: [ArtCollection] { catalog?.collections ?? [] }

    public var collectionWorks: [ArtWork] {
        guard let catalog, let collection else { return [] }
        let lead = catalog.leadWork(of: collection)
        let rest = catalog.works(in: collection.id).filter { $0 != lead }
        return [lead].compactMap { $0 } + rest
    }

    public var paletteGrid: [LensPaletteSwatch] { LensPaletteSwatch.grid }

    public var suggestedPalette: LensPaletteSwatch? {
        LensPaletteSwatch.named(Lens.suggestedPalette)
    }

    public var supportsIcons: Bool { icons?.supportsAlternateIcons == true }

    public var suggestedIcon: AppIcon? { palette?.appIcon }

    public var iconChoices: [AppIcon] { LensIcons.choices(suggested: suggestedIcon) }

    public func isChosen(_ swatch: LensPaletteSwatch) -> Bool { palette == swatch }

    public func isChosen(_ collection: ArtCollection) -> Bool {
        lens?.artCollection == collection.id
    }

    public func choose(_ swatch: LensPaletteSwatch) async {
        await update { $0.palette = swatch.rawValue }
    }

    public func choose(_ collection: ArtCollection) async {
        await update { $0.artCollection = collection.id }
    }
}
