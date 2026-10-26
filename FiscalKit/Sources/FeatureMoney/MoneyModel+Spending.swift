import FeatureCore
import FiscalDomain
import Foundation

extension MoneyModel {
    public static let spenderPreview = 8

    public var spendYear: Int? { places?.year ?? overview?.year }

    public var categories: [AmountBar] {
        let items =
            place?.quota.byCategory ?? (isCountry ? overview?.quota.byCategory ?? [] : [])
        return MoneyText.bars(
            items, id: \.category, title: \.category, cents: \.cents,
            kind: { MoneyKind.category($0.category) })
    }

    public var quotaComposition: [AmountBar] {
        MoneyText.composition(categories, slices: .chartCompositionSlices)
    }

    public var spenders: [MoneyPlaces.Spender] { place?.quota.spenders ?? [] }

    public var spenderPreview: [MoneyPlaces.Spender] {
        Array(spenders.prefix(Self.spenderPreview))
    }

    public var spendHeadline: String? {
        guard let place, let year = spendYear.map(String.init) else { return nil }
        let classified = place.quota.classified
        guard classified > 0 else {
            return String(
                appLocalized: "There are too few peers with data in \(year) to compare.")
        }
        let count = PublicFormat.number(place.quota.spenders.count)
        let total = PublicFormat.number(classified)
        if place.quota.spenders.isEmpty {
            return isCountry
                ? String(appLocalized: "No one spends above the peer range in \(year).")
                : String(
                    appLocalized: "No one from \(scopeName) spends above the peer range in \(year)."
                )
        }
        return isCountry
            ? String(
                appLocalized:
                    "\(count) of \(total) deputies and senators spend above the peer range in \(year)."
            )
            : String(
                appLocalized:
                    "\(count) of \(total) from \(scopeName) spend above the peer range in \(year).")
    }

    public var categoriesHeadline: String? {
        guard let first = categories.first, let year = spendYear.map(String.init) else {
            return nil
        }
        let total = PublicFormat.compactMoney(cents: categories.map(\.cents).reduce(0, +))
        return String(
            appLocalized: "\(total) spent in \(year). The largest item: \(first.title).")
    }

    public var spendScopeNote: String? {
        guard !isCountry, place == nil else { return nil }
        return String(
            appLocalized:
                "The allowance by state isn't published yet, so this block shows Brazil and doesn't follow the state picked."
        )
    }

    public func monthlyText(_ cents: Int) -> String {
        PeerClassification.Metric.quota.format(Double(cents))
    }

    public func medianText(_ spender: MoneyPlaces.Spender) -> String {
        let median = monthlyText(spender.medianCents)
        return spender.house == "senado"
            ? String(appLocalized: "Senate median: \(median)")
            : String(appLocalized: "Chamber median: \(median)")
    }

    public func accessibilityLabel(for spender: MoneyPlaces.Spender) -> String {
        let card = spender.person
        let parts = [
            card.name, card.party, card.officeTitle, spender.band.title,
            monthlyText(spender.monthlyCents), medianText(spender), spender.topCategory,
        ]
        return parts.compactMap(\.self).joined(separator: ", ")
    }

    public var campaigns: MoneyOverview.Campaigns? { overview?.campaigns }

    public var campaignOrigins: [AmountBar] {
        MoneyText.bars(
            campaigns?.byOrigin ?? [], id: \.origin, title: \.origin, cents: \.cents,
            kind: { MoneyKind.origin($0.origin) })
    }

    public var campaignOriginsHeadline: String? {
        guard let first = campaignOrigins.first, first.cents > 0 else { return nil }
        return String(appLocalized: "\(first.percent) came from \(first.title)")
    }

    public var campaignsHeadline: String {
        guard let campaigns else {
            return String(appLocalized: "The electoral court hasn't published campaign money yet.")
        }
        let year = String(campaigns.year)
        let raised = PublicFormat.compactMoney(cents: campaigns.revenueCents)
        return String(appLocalized: "Campaigns in \(year) raised \(raised)")
    }

    public var campaignFigures: (raised: String, spent: String) {
        (
            PublicFormat.compactMoney(cents: campaigns?.revenueCents),
            PublicFormat.compactMoney(cents: campaigns?.expenseCents)
        )
    }

    public var campaignPlaceLine: String? {
        guard !isCountry else { return nil }
        guard let raised = place?.campaigns, raised.people > 0 else {
            return String(appLocalized: "There are no campaign figures for \(scopeName) yet.")
        }
        let people = PublicFormat.number(raised.people)
        let value = PublicFormat.compactMoney(cents: raised.revenueCents)
        let years = raised.years.map(String.init).formatted(.list(type: .and).locale(.app))
        return String(
            appLocalized:
                "The winning campaigns of the \(people) in office from \(scopeName) raised \(value) (\(years))."
        )
    }

    public var campaignScopeNote: String? {
        guard !isCountry else { return nil }
        return String(
            appLocalized:
                "The origin of the money is published only for the whole country, so the chart shows Brazil."
        )
    }

    public var revenue: MoneyOverview.Revenue? { overview?.revenue }

    public var revenueTiles: [StateTile] { StateTile.tiles(revenue?.byState ?? []) }

    public var revenueHeadline: String {
        guard let revenue else {
            return String(
                appLocalized: "The federal revenue service hasn't closed a full year yet.")
        }
        let total = PublicFormat.compactMoney(cents: revenue.totalCents)
        return String(appLocalized: "Federal revenue in \(String(revenue.year)): \(total)")
    }

    public var revenueFocus: String? { isCountry ? nil : scopeUF }

    public var revenueStateLine: String? {
        guard !isCountry, revenue != nil else { return nil }
        guard let tile = revenueTiles.first(where: { $0.uf == scopeUF }), tile.cents != nil else {
            return String(appLocalized: "There is no revenue figure for \(scopeName).")
        }
        return String(
            appLocalized: "\(scopeName) paid \(tile.value), \(tile.percent) of the total.")
    }
}
