import FiscalDomain
import Foundation

public enum AppIcon: String, CaseIterable, Identifiable, Sendable {
    case standard
    case amazonDay
    case amazonRiver
    case themeForest
    case themeAnnatto
    case themeIndigo
    case themeIpe
    case themeSavanna
    case themeSea
    case themeGraphite
    case themeSand
    case faunaJaguar
    case faunaMacaw
    case faunaToucan
    case faunaTamarin
    case faunaDolphin
    case faunaAnteater
    case partyAgir
    case partyAvante
    case partyCidadania
    case partyDc
    case partyDemocrata
    case partyMdb
    case partyMissao
    case partyMobiliza
    case partyNovo
    case partyPcb
    case partyPcdob
    case partyPco
    case partyPdt
    case partyPl
    case partyPodemos
    case partyPp
    case partyPrd
    case partyPrtb
    case partyPsb
    case partyPsd
    case partyPsdb
    case partyPsol
    case partyPstu
    case partyPt
    case partyPv
    case partyRede
    case partyRepublicanos
    case partySolidariedade
    case partyUniao
    case partyUp

    public enum Collection: CaseIterable, Identifiable, Sendable {
        case main, themes, fauna, parties

        public var id: Self { self }

        public var title: String {
            switch self {
            case .main: String(appLocalized: "Main")
            case .themes: String(appLocalized: "Themes")
            case .fauna: String(appLocalized: "Brazilian Wildlife")
            case .parties: String(appLocalized: "Parties")
            }
        }

        public static func visible(partyIcons: Bool) -> [Collection] {
            allCases.filter { $0 != .parties || partyIcons }
        }

        public var icons: [AppIcon] {
            let icons = AppIcon.allCases.filter { $0.collection == self }
            guard self == .parties else { return icons }
            return icons.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        }
    }

    public var id: String { rawValue }

    public init(assetName: String?) {
        self = Self.allCases.first { $0.assetName == assetName } ?? .standard
    }

    public var assetName: String? {
        switch self {
        case .standard: nil
        default: "FiscalIcon" + rawValue.prefix(1).uppercased() + rawValue.dropFirst()
        }
    }

    public var previewName: String { assetName ?? "FiscalIcon" }

    public var collection: Collection {
        switch self {
        case .standard, .amazonDay, .amazonRiver: .main
        case .themeForest, .themeAnnatto, .themeIndigo, .themeIpe, .themeSavanna, .themeSea,
            .themeGraphite, .themeSand:
            .themes
        case .faunaJaguar, .faunaMacaw, .faunaToucan, .faunaTamarin, .faunaDolphin, .faunaAnteater:
            .fauna
        default: .parties
        }
    }

    public var title: String {
        if let name = Self.partyNames[self] { return name }
        return localizedTitle
    }

    private static let partyNames: [AppIcon: String] = [
        .partyAgir: "Agir",
        .partyAvante: "Avante",
        .partyCidadania: "Cidadania",
        .partyDc: "DC",
        .partyDemocrata: "Democrata",
        .partyMdb: "MDB",
        .partyMissao: "Missão",
        .partyMobiliza: "Mobiliza",
        .partyNovo: "Novo",
        .partyPcb: "PCB",
        .partyPcdob: "PCdoB",
        .partyPco: "PCO",
        .partyPdt: "PDT",
        .partyPl: "PL",
        .partyPodemos: "Podemos",
        .partyPp: "PP",
        .partyPrd: "PRD",
        .partyPrtb: "PRTB",
        .partyPsb: "PSB",
        .partyPsd: "PSD",
        .partyPsdb: "PSDB",
        .partyPsol: "PSOL",
        .partyPstu: "PSTU",
        .partyPt: "PT",
        .partyPv: "PV",
        .partyRede: "Rede",
        .partyRepublicanos: "Republicanos",
        .partySolidariedade: "Solidariedade",
        .partyUniao: "União Brasil",
        .partyUp: "UP",
    ]

    private var localizedTitle: String {
        switch self {
        case .standard: String(appLocalized: "Amazon Dawn")
        case .amazonDay: String(appLocalized: "Amazon Day")
        case .amazonRiver: String(appLocalized: "Amazon River")
        case .themeForest: String(appLocalized: "Forest")
        case .themeAnnatto: String(appLocalized: "Annatto")
        case .themeIndigo: String(appLocalized: "Indigo")
        case .themeIpe: String(appLocalized: "Ipê")
        case .themeSavanna: String(appLocalized: "Savanna")
        case .themeSea: String(appLocalized: "Sea")
        case .themeGraphite: String(appLocalized: "Graphite")
        case .themeSand: String(appLocalized: "Sand")
        case .faunaJaguar: String(appLocalized: "Jaguar")
        case .faunaMacaw: String(appLocalized: "Hyacinth Macaw")
        case .faunaToucan: String(appLocalized: "Toucan")
        case .faunaTamarin: String(appLocalized: "Golden Lion Tamarin")
        case .faunaDolphin: String(appLocalized: "Pink River Dolphin")
        case .faunaAnteater: String(appLocalized: "Giant Anteater")
        default: rawValue
        }
    }
}
