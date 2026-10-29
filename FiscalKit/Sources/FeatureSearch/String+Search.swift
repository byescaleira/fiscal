import FiscalDomain
import Foundation

extension String {
    var searchFolded: String {
        let folded = folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: Locale(identifier: "pt_BR"))
        let scalars = folded.unicodeScalars.map { scalar in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : " "
        }
        return String(scalars)
    }

    var searchWords: [String] {
        searchFolded.split(whereSeparator: \.isWhitespace).map(String.init)
    }
}

extension [String] {
    func matchesSearch(_ terms: [String]) -> Bool {
        terms.allSatisfy { term in contains { $0.hasPrefix(term) } }
    }
}

extension Office {
    var searchAliases: String {
        switch self {
        case .president: "presidente presidenta"
        case .vicePresident: "vice presidente presidenta"
        case .senator: "senador senadora senado"
        case .federalDeputy: "deputado deputada federal camara"
        case .governor: "governador governadora"
        case .viceGovernor: "vice governador governadora"
        case .stateDeputy: "deputado deputada estadual distrital assembleia"
        case .mayor: "prefeito prefeita prefeitura"
        case .viceMayor: "vice prefeito prefeita prefeitura"
        case .cityCouncilor: "vereador vereadora camara municipal"
        }
    }
}

extension PersonStatus {
    var searchAliases: String {
        switch self {
        case .inOffice: "em exercicio"
        case .electedAwaiting: "eleito eleita 2026 posse"
        case .onLeave: "licenca licenciado licenciada"
        }
    }
}
