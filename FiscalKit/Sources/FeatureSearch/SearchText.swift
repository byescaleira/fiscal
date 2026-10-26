import FiscalDomain
import Foundation

enum SearchText {
    static func fold(_ text: String) -> String {
        let folded = text.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: Locale(identifier: "pt_BR"))
        let scalars = folded.unicodeScalars.map { scalar in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : " "
        }
        return String(scalars)
    }

    static func words(_ text: String) -> [String] {
        fold(text).split(whereSeparator: \.isWhitespace).map(String.init)
    }

    static func matches(_ terms: [String], in words: [String]) -> Bool {
        terms.allSatisfy { term in words.contains { $0.hasPrefix(term) } }
    }

    static func aliases(for office: Office) -> String {
        switch office {
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

    static func aliases(for status: PersonStatus) -> String {
        switch status {
        case .inOffice: "em exercicio"
        case .electedAwaiting: "eleito eleita 2026 posse"
        case .onLeave: "licenca licenciado licenciada"
        }
    }
}
