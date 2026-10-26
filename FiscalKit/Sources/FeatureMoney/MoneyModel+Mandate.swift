import FeatureCore
import FiscalDomain
import Foundation

extension MoneyModel {
    private var deputy: MandateCost.RoleCost? {
        mandate?.roles.first { $0.role == .federalDeputy }
    }

    private var quotaItem: MandateCost.Item? {
        mandate?.roles.lazy.flatMap(\.items).first { $0.kind == .quota && $0.byState != nil }
    }

    public var mandateStates: [String] {
        (quotaItem?.byState ?? []).map { $0.uf.lowercased() }
            .sorted {
                RaceText.scope($0).localizedStandardCompare(RaceText.scope($1)) == .orderedAscending
            }
    }

    public var hasMandate: Bool { !(mandate?.roles.isEmpty ?? true) }

    public var mandateUF: String {
        let states = mandateStates
        if states.contains(selectedUF) { return selectedUF }
        if states.contains(MandateText.fallbackUF) { return MandateText.fallbackUF }
        return states.first ?? selectedUF
    }

    public var mandateUFName: String { RaceText.scope(mandateUF) }

    public var mandateSegments: [MandateSegment] {
        let uf = mandateUF
        return (mandate?.roles ?? []).flatMap { role in
            let parts = role.items.compactMap { item in
                item.cents(uf: uf).map { (item.kind, $0) }
            }
            return parts.enumerated().map { index, part in
                MandateSegment(
                    role: role.role, kind: part.0, cents: part.1, isLast: index == parts.count - 1)
            }
        }
    }

    public var mandateTotals: [MandateRoleTotal] {
        let uf = mandateUF
        return (mandate?.roles ?? []).map { role in
            MandateRoleTotal(
                role: role.role,
                monthlyCents: role.items.compactMap { $0.cents(uf: uf) }.reduce(0, +),
                unpublished: role.unpublished)
        }
    }

    public var mandateHighlight: MandateRoleTotal? {
        mandateTotals.first { $0.role == .federalDeputy } ?? mandateTotals.first
    }

    public var mandateHighlightChip: String {
        guard let highlight = mandateHighlight else { return "" }
        let place = quotaItem == nil ? "" : " · \(mandateUFName)"
        return "\(highlight.title)\(place)".uppercased(with: .app)
    }

    public var mandateKinds: [MandateCost.Kind] {
        MandateCost.Kind.allCases.filter { kind in mandateSegments.contains { $0.kind == kind } }
    }

    public var mandateComparison: String? {
        guard
            let salary = deputy?.items.first(where: { $0.kind == .salary })?.monthlyCents,
            let wage = mandate?.minimumWage?.monthlyCents, wage > 0
        else { return nil }
        let wages = MandateText.multiple(Double(salary) / Double(wage))
        guard let income = mandate?.laborIncome?.monthlyCents, income > 0 else {
            return String(appLocalized: "A federal deputy's salary equals \(wages) minimum wages.")
        }
        let times = MandateText.multiple(Double(salary) / Double(income))
        return String(
            appLocalized:
                "A federal deputy's salary equals \(wages) minimum wages and \(times) times the average labor income in Brazil."
        )
    }

    public var mandateReferenceLines: [String] {
        var lines: [String] = []
        if let wage = mandate?.minimumWage {
            let value = PublicFormat.money(cents: wage.monthlyCents)
            let act = MandateText.act(wage.act)
            lines.append(String(appLocalized: "Minimum wage: \(value) (\(act))"))
        }
        if let income = mandate?.laborIncome {
            let value = PublicFormat.money(cents: income.monthlyCents)
            let period = income.period ?? PublicFormat.missing
            lines.append(
                String(appLocalized: "Average monthly labor income: \(value) (IBGE, \(period))"))
        }
        return lines
    }

    public var mandateActLines: [String] {
        guard let mandate else { return [] }
        var seen = Set<String>()
        return mandate.roles.flatMap(\.items).compactMap { item in
            let line = MandateText.itemLine(item)
            return seen.insert(line).inserted ? line : nil
        }
    }

    public var mandateMissingNote: String? {
        let missing = mandateTotals.filter { !$0.unpublished.isEmpty }
        guard !missing.isEmpty else { return nil }
        return missing.map { total in
            let kinds = total.unpublished.map(MandateText.kindTitle)
                .formatted(.list(type: .and).locale(.app))
            return String(
                appLocalized:
                    "\(total.title): \(kinds) have no current official table published, so they are left out of the sum."
            )
        }
        .joined(separator: " ")
    }

    public var mandateCheckedLine: String? {
        guard let checked = mandate?.checkedAt else { return nil }
        return String(appLocalized: "Values checked at the source on \(MandateText.day(checked))")
    }

    public var quotaStateBars: [QuotaStateBar] {
        let uf = mandateUF
        return (quotaItem?.byState ?? [])
            .map {
                QuotaStateBar(
                    uf: $0.uf.lowercased(), cents: $0.monthlyCents,
                    isSelected: $0.uf.lowercased() == uf)
            }
            .sorted { ($1.cents, $0.uf) < ($0.cents, $1.uf) }
    }

    public var selectedQuotaBar: QuotaStateBar? { quotaStateBars.first(where: \.isSelected) }

    public var quotaRangeHeadline: String? {
        let bars = quotaStateBars
        guard let high = bars.first, let low = bars.last, bars.count > 1 else { return nil }
        let gap = PublicFormat.money(cents: high.cents - low.cents)
        return String(
            appLocalized:
                "Highest: \(high.title), \(high.value). Lowest: \(low.title), \(low.value). Difference: \(gap) per month."
        )
    }

    public var quotaActLine: String? {
        quotaItem.map { MandateText.act($0.act) }
    }
}
