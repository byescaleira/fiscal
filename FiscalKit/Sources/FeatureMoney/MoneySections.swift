import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct SalariesSection: View {
    @Environment(MoneyModel.self) private var money

    var body: some View {
        if !money.salaries.isEmpty {
            Section {
                SalaryLollipopChart(salaries: money.salaries)
                    .padding(.vertical, .spaceXS)
                ForEach(money.salaries) { SalaryRow(salary: $0) }
            } header: {
                Text("Salaries").sectionTitle()
            } footer: {
                VStack(alignment: .leading, spacing: .space2XS) {
                    Text(
                        "Gross monthly pay, before taxes. Each one is set by the law shown under the office."
                    )
                    Text(verbatim: money.sourceLine(for: .salaries))
                }
            }
        }
    }
}

private struct SalaryRow: View {
    let salary: MoneyModel.Salary

    var body: some View {
        AdaptiveRow(spacing: .spaceM) {
            HStack(spacing: .spaceM) {
                SymbolBadge(salary.symbol, color: .companion, size: .badgeM)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: .spaceHairline) {
                    Text(verbatim: salary.title).font(.rowTitle)
                    Label {
                        Text(verbatim: salary.law)
                    } icon: {
                        Image(systemName: "text.book.closed")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: .spaceS)
            VStack(alignment: .trailing, spacing: .spaceHairline) {
                Text(verbatim: salary.value).font(.amountRow).monospacedDigit().amountLine()
                Text("per month").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, .space2XS)
        .accessibilityElement(children: .combine)
    }
}

struct CampaignsSection: View {
    @Environment(MoneyModel.self) private var money

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: .spaceM) {
                Text(verbatim: money.campaignsHeadline).font(.headline)
                AdaptiveRow(spacing: .spaceM) {
                    MoneyFigure(label: "Raised", value: money.campaignFigures.raised)
                    MoneyFigure(label: "Spent", value: money.campaignFigures.spent)
                }
                if !money.campaignOrigins.isEmpty {
                    if let headline = money.campaignOriginsHeadline {
                        Text(verbatim: headline).font(.subheadline.weight(.semibold))
                    }
                    OriginColumnsChart(bars: money.campaignOrigins)
                }
            }
            .padding(.vertical, .spaceXS)
        } header: {
            Text("Where campaign money comes from").sectionTitle()
        } footer: {
            VStack(alignment: .leading, spacing: .space2XS) {
                Text(
                    "All candidates in the last general election, by origin of the money. Touch a column to see its total."
                )
                Text(verbatim: money.sourceLine(for: .campaigns))
            }
        }
    }
}

struct RevenueSection: View {
    @Environment(MoneyModel.self) private var money

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: .spaceM) {
                Text(verbatim: money.revenueHeadline).font(.headline)
                if money.revenueStates.isEmpty {
                    MoneyFigure(label: "Collected", value: PublicFormat.missing)
                } else {
                    StateTileMap(tiles: money.revenueTiles)
                }
            }
            .padding(.vertical, .spaceXS)
        } header: {
            Text("Taxes collected by state").sectionTitle()
        } footer: {
            VStack(alignment: .leading, spacing: .space2XS) {
                Text(
                    "Federal taxes paid in each state in the last full year. The darker the state, the more it paid. Touch a state to see its total."
                )
                Text(verbatim: money.sourceLine(for: .revenue))
            }
        }
    }
}

struct MoneyFigure: View {
    let label: LocalizedStringKey
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceHairline) {
            Text(label)
                .font(.chipLabel)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            Text(verbatim: value)
                .font(.amountTitle)
                .monospacedDigit()
                .amountLine()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.spaceM)
        .tintedCard(.secondary)
        .accessibilityElement(children: .combine)
    }
}
