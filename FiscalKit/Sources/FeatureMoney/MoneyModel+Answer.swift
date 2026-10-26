import FeatureCore
import FiscalDomain
import Foundation

extension MoneyModel {
    public var answer: Answer? {
        if let place, let ceiling = place.ceilingMonthlyCents, ceiling > 0 {
            return congressAnswer(place: place, ceiling: ceiling)
        }
        if let highlight = mandateHighlight, highlight.monthlyCents > 0 {
            return mandateAnswer(highlight)
        }
        guard let overview, quotaCents > 0 else { return nil }
        let year = String(overview.year)
        return Answer(
            kicker: String(appLocalized: "Office allowance · \(year)").uppercased(with: .app),
            value: PublicFormat.compactMoney(cents: quotaCents), cents: quotaCents,
            unit: String(appLocalized: "in \(year)"),
            sentence: String(appLocalized: "Spent by federal deputies and senators in \(year)"),
            comparison: nil, fact: nil,
            caveat: isCountry
                ? nil
                : String(appLocalized: "There are no figures by state yet. Showing Brazil."))
    }

    private func congressAnswer(place: MoneyPlaces.Place, ceiling: Int) -> Answer {
        let deputies = PublicFormat.number(place.deputies)
        let senators = PublicFormat.number(place.senators)
        let sentence =
            isCountry
            ? String(
                appLocalized:
                    "The most the law allows each month for the \(deputies) federal deputies and \(senators) senators in office."
            )
            : String(
                appLocalized:
                    "The most the law allows each month for the \(deputies) federal deputies and \(senators) senators from \(scopeName)."
            )
        return Answer(
            kicker: String(appLocalized: "Congress · \(scopeName)").uppercased(with: .app),
            value: PublicFormat.compactMoney(cents: ceiling), cents: ceiling,
            unit: String(appLocalized: "per month"), sentence: sentence,
            comparison: wagesLine(ceiling), fact: spentLine(place),
            caveat: ceilingCaveat)
    }

    private func mandateAnswer(_ highlight: MandateRoleTotal) -> Answer {
        let sentence =
            isCountry
            ? String(
                appLocalized:
                    "The most one federal deputy's mandate can cost each month, with the average allowance cap of the states."
            )
            : String(
                appLocalized:
                    "The most one federal deputy's mandate from \(scopeName) can cost each month.")
        return Answer(
            kicker: mandateHighlightChip, value: highlight.monthly, cents: highlight.monthlyCents,
            unit: String(appLocalized: "per month"), sentence: sentence,
            comparison: wagesLine(highlight.monthlyCents), fact: nil, caveat: ceilingCaveat)
    }

    public var answerSourceLine: String {
        var seen = Set<String>()
        let congress = (places?.sources ?? []).filter { $0.id == "camara" || $0.id == "senado" }
        let all = ((mandate?.sources ?? []) + (place == nil ? [] : congress))
            .filter { seen.insert($0.id).inserted }
        return all.isEmpty ? sourceLine(for: .quota) : MoneyText.sourceLine(all)
    }

    private func wagesLine(_ cents: Int) -> String? {
        guard let wage = minimumWageCents else { return nil }
        let wages = PublicFormat.number(Int((Double(cents) / Double(wage)).rounded()))
        return String(appLocalized: "Equal to \(wages) minimum wages every month")
    }

    private func spentLine(_ place: MoneyPlaces.Place) -> String? {
        guard place.quota.totalCents > 0, let year = places?.year else { return nil }
        let spent = PublicFormat.compactMoney(cents: place.quota.totalCents)
        return String(appLocalized: "Office allowance actually spent in \(String(year)): \(spent)")
    }

    private var ceilingCaveat: String {
        let base = String(
            appLocalized:
                "It's a ceiling: salary, office allowance, staff budget and housing allowance at full value. Not everyone uses the whole allowance or the housing allowance."
        )
        return [base, congressMissingNote].compactMap(\.self).joined(separator: " ")
    }
}
