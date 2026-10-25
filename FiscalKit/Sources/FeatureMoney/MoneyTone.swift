import FiscalDomain
import Foundation

public enum MoneyTone: String, CaseIterable, Sendable {
    case teal, denim, plum, brown, orange
}

public struct MoneyKind: Equatable, Sendable {
    public let symbol: String
    public let tone: MoneyTone

    public init(symbol: String, tone: MoneyTone) {
        self.symbol = symbol
        self.tone = tone
    }

    private static let categories: [(keys: [String], kind: MoneyKind)] = [
        (["passage", "aére", "aere", "voo"], MoneyKind(symbol: "airplane", tone: .denim)),
        (["divulga", "publicidade"], MoneyKind(symbol: "megaphone", tone: .orange)),
        (
            ["escritório", "escritorio", "imóvel", "imovel"],
            MoneyKind(symbol: "building.2", tone: .brown)
        ),
        (["combust", "lubrific"], MoneyKind(symbol: "fuelpump", tone: .plum)),
        (
            ["veículo", "veiculo", "táxi", "taxi", "pedágio", "pedagio", "estacionamento"],
            MoneyKind(symbol: "car", tone: .teal)
        ),
        (["telefon", "postais", "correio"], MoneyKind(symbol: "phone", tone: .teal)),
        (["aliment", "refei"], MoneyKind(symbol: "fork.knife", tone: .orange)),
        (["hosped", "hotel"], MoneyKind(symbol: "bed.double", tone: .plum)),
        (
            ["consultor", "pesquisa", "trabalhos técnicos"],
            MoneyKind(symbol: "doc.text.magnifyingglass", tone: .denim)
        ),
        (["segurança", "seguranca"], MoneyKind(symbol: "lock.shield", tone: .brown)),
        (["curso", "evento", "palestra"], MoneyKind(symbol: "graduationcap", tone: .denim)),
        (
            ["assinatura", "publicaç", "publicac", "software"],
            MoneyKind(symbol: "newspaper", tone: .plum)
        ),
    ]

    private static let origins: [(keys: [String], kind: MoneyKind)] = [
        (
            ["fundo especial", "fefc", "eleitoral"],
            MoneyKind(symbol: "building.columns", tone: .denim)
        ),
        (["partidário", "partidario", "partido"], MoneyKind(symbol: "flag", tone: .plum)),
        (
            ["pessoas físicas", "pessoas fisicas", "doaç", "doac"],
            MoneyKind(symbol: "person.3", tone: .teal)
        ),
        (["próprios", "proprios"], MoneyKind(symbol: "person", tone: .brown)),
        (["internet", "financiamento coletivo"], MoneyKind(symbol: "globe", tone: .orange)),
    ]

    public static let other = MoneyKind(symbol: "doc.text", tone: .brown)
    public static let state = MoneyKind(symbol: "map", tone: .denim)

    public static func category(_ name: String) -> MoneyKind {
        match(name, in: categories) ?? other
    }

    public static func origin(_ name: String) -> MoneyKind {
        match(name, in: origins) ?? MoneyKind(symbol: "banknote", tone: .brown)
    }

    public static func office(_ office: Office) -> String {
        switch office {
        case .president: "star"
        case .vicePresident: "star.leadinghalf.filled"
        case .senator: "building.columns"
        case .federalDeputy: "person.3"
        case .governor: "building.2"
        case .viceGovernor: "building"
        case .stateDeputy: "person.2"
        case .mayor: "flag"
        case .viceMayor: "flag.2.crossed"
        case .cityCouncilor: "person.3.sequence"
        }
    }

    private static func match(_ name: String, in table: [(keys: [String], kind: MoneyKind)])
        -> MoneyKind?
    {
        let text = name.lowercased()
        return table.first { entry in entry.keys.contains { text.contains($0) } }?.kind
    }
}
