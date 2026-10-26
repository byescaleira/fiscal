import FiscalDesignSystem
import FiscalDomain
import FiscalResource
import Foundation

struct LensSummary {
    static let spectrum: [PoliticalStance] = [.left, .centerLeft, .center, .centerRight, .right]

    let stance: PoliticalStance?
    let palette: LensPaletteSwatch?
    let work: ArtWork?
    let themes: [Theme]

    init(lens: Lens?, catalog: ArtCatalog?) {
        stance = lens?.stance
        palette = LensPaletteSwatch.named(lens?.palette)
        themes = lens?.themes ?? []
        let collection = lens?.artCollection.flatMap { catalog?.collection(id: $0) }
        work = collection.flatMap { catalog?.leadWork(of: $0) }
    }

    var isSet: Bool { stance != nil }

    var stanceTitle: String {
        stance?.effective.title ?? String(appLocalized: "No lens yet")
    }

    var isOnSpectrum: Bool {
        stance.map { Self.spectrum.contains($0) } ?? false
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
