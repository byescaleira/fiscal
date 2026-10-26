import Foundation

public enum RaceText {
    private static let stateNames: [String: String] = [
        "ac": "Acre", "al": "Alagoas", "am": "Amazonas", "ap": "Amapá", "ba": "Bahia",
        "ce": "Ceará", "df": "Distrito Federal", "es": "Espírito Santo", "go": "Goiás",
        "ma": "Maranhão", "mg": "Minas Gerais", "ms": "Mato Grosso do Sul", "mt": "Mato Grosso",
        "pa": "Pará", "pb": "Paraíba", "pe": "Pernambuco", "pi": "Piauí", "pr": "Paraná",
        "rj": "Rio de Janeiro", "rn": "Rio Grande do Norte", "ro": "Rondônia", "rr": "Roraima",
        "rs": "Rio Grande do Sul", "sc": "Santa Catarina", "se": "Sergipe", "sp": "São Paulo",
        "to": "Tocantins",
    ]

    public static func office(_ office: Race.Office) -> String {
        switch office {
        case .president: String(appLocalized: "President")
        case .governor: String(appLocalized: "Governor")
        }
    }

    public static func scope(_ uf: String) -> String {
        uf == "br" ? String(appLocalized: "Brazil") : stateNames[uf] ?? uf.uppercased()
    }

    public static func title(office: Race.Office, uf: String) -> String {
        "\(Self.office(office)) · \(scope(uf))"
    }

    public static func percent(_ value: Double) -> String {
        (value / 100).formatted(.percent.precision(.fractionLength(2)).locale(.app))
    }

    public static func shortPercent(_ value: Double) -> String {
        (value / 100).formatted(.percent.precision(.fractionLength(1)).locale(.app))
    }

    public static func votes(_ value: Int) -> String {
        value.formatted(.number.locale(.app))
    }

    public static func compactVotes(_ value: Int) -> String {
        value.formatted(
            .number.notation(.compactName).precision(.fractionLength(0...1)).locale(.app))
    }

    public static func sections(counted: Int, total: Int) -> String {
        let counted = counted.formatted(.number.locale(.app))
        let total = total.formatted(.number.locale(.app))
        return String(appLocalized: "\(counted) of \(total) polling stations")
    }

    public static func time(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: .app))
    }

    public static func elected(_ name: String) -> String {
        String(appLocalized: "\(name) elected")
    }
}
