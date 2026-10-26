import FiscalDomain
import Foundation

public enum IndicatorFormat {
    public static func value(
        _ value: Double?, kind: IndicatorKind, locale: Locale = .app
    ) -> String {
        guard let value, value.isFinite else { return PublicFormat.missing }
        switch kind {
        case .price:
            return value.formatted(
                .currency(code: "BRL").precision(.fractionLength(2)).locale(locale))
        case .index:
            return value.formatted(.number.precision(.fractionLength(1)).locale(locale))
        }
    }

    public static func change(_ fraction: Double?, locale: Locale = .app) -> String {
        guard let fraction, fraction.isFinite else { return PublicFormat.missing }
        return fraction.formatted(
            .percent.precision(.fractionLength(1)).sign(strategy: .always(includingZero: false))
                .locale(locale))
    }

    public static func month(_ day: CalendarDay?, calendar: Calendar = FiscalCalendar.current)
        -> String
    {
        guard let day else { return PublicFormat.missing }
        return day.date(in: calendar).formatted(
            .dateTime.month(.abbreviated).year().locale(.app))
    }

    public static func place(scope: String) -> String {
        scope == Indicator.brazil
            ? String(appLocalized: "in Brazil")
            : String(appLocalized: "in \(scope.uppercased())")
    }

    public static func subject(id: String, name: String) -> String {
        switch id {
        case "gasolina": String(appLocalized: "gasoline")
        case "etanol": String(appLocalized: "ethanol")
        case "diesel-s10": String(appLocalized: "S10 diesel")
        case "glp": String(appLocalized: "a cooking gas cylinder")
        case "ipca": String(appLocalized: "official inflation (IPCA)")
        case "ipca-alimentacao-domicilio": String(appLocalized: "the price of food at home")
        case "ipca-energia-eletrica": String(appLocalized: "the price of electricity")
        case "ipca-aluguel": String(appLocalized: "the price of rent")
        case "ipca-gasolina": String(appLocalized: "the price of gasoline in the IPCA")
        default: name
        }
    }

    public static func symbol(id: String) -> String {
        switch id {
        case "gasolina", "etanol", "diesel-s10", "ipca-gasolina": "fuelpump"
        case "glp": "flame"
        case "ipca-alimentacao-domicilio": "cart"
        case "ipca-energia-eletrica": "bolt"
        case "ipca-aluguel": "house"
        default: "chart.line.uptrend.xyaxis"
        }
    }

    public static func unitLine(unit: String, kind: IndicatorKind) -> String {
        switch kind {
        case .price: String(appLocalized: "Monthly average price, \(unit)")
        case .index: String(appLocalized: "Monthly IPCA index (IBGE)")
        }
    }
}
