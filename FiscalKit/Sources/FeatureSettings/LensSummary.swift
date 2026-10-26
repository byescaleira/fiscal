import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import FiscalResource
import Foundation

struct LensSummary {
    let isSet: Bool
    let prefersNotToSay: Bool
    let cards: [PersonCard]
    let palette: LensPaletteSwatch?
    let work: ArtWork?
    let themes: [Theme]

    init(lens: Lens?, catalog: ArtCatalog?, cards: [PersonCard] = []) {
        isSet = lens?.hasChoice == true
        prefersNotToSay = lens?.prefersNotToSay == true
        self.cards = cards
        palette = LensPaletteSwatch.named(lens?.palette)
        themes = lens?.themes ?? []
        let collection = lens?.artCollection.flatMap { catalog?.collection(id: $0) }
        work = collection.flatMap { catalog?.leadWork(of: $0) }
    }

    var title: String {
        if !cards.isEmpty { return SupportedPeople.names(cards) }
        if prefersNotToSay { return String(appLocalized: "Prefer not to say") }
        if isSet { return String(appLocalized: "Your lens") }
        return String(appLocalized: "No lens yet")
    }

    var themesText: String? {
        guard !themes.isEmpty else { return nil }
        return themes.map(\.title).formatted(.list(type: .and).locale(.app))
    }

    var paletteTitle: String? {
        switch palette {
        case .forest: String(appLocalized: "Forest and gold")
        case .annatto: String(appLocalized: "Annatto")
        case .indigo: String(appLocalized: "Indigo")
        case .ipe: String(appLocalized: "Ipê")
        case .savanna: String(appLocalized: "Cerrado")
        case .sea: String(appLocalized: "Sea")
        case .graphite: String(appLocalized: "Graphite")
        case .sand: String(appLocalized: "Sand")
        case nil: nil
        }
    }

    var credit: String? {
        guard let work else { return nil }
        let license =
            work.license.hasPrefix("PD") ? String(appLocalized: "Public domain") : work.license
        return String(appLocalized: "Art: \(work.artist) · \(license)")
    }
}
