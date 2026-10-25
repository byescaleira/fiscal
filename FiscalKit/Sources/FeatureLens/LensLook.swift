import FiscalDesignSystem
import FiscalDomain
import FiscalResource
import Foundation

extension LensPaletteSwatch {
    public var title: String {
        switch self {
        case .forest: String(appLocalized: "Forest and gold")
        case .annatto: String(appLocalized: "Annatto")
        case .indigo: String(appLocalized: "Indigo")
        case .ipe: String(appLocalized: "Ipê")
        case .savanna: String(appLocalized: "Cerrado")
        case .sea: String(appLocalized: "Sea")
        case .graphite: String(appLocalized: "Graphite")
        case .sand: String(appLocalized: "Sand")
        }
    }

    public var pairText: String {
        String(appLocalized: "Pairs with \(mirror.title)")
    }
}

extension ArtWork {
    public var isPublicDomain: Bool { license.hasPrefix("PD") }

    public var licenseTitle: String {
        isPublicDomain ? String(appLocalized: "Public domain") : license
    }

    public var caption: String { "\(title), \(year)" }

    public var accessibilityCredit: String {
        String(appLocalized: "Artwork: \(title), by \(artist), \(year). \(licenseTitle).")
    }
}
