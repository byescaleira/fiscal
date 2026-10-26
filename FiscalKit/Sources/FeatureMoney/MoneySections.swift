import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct CampaignsSection: View {
    @Environment(MoneyModel.self) private var money

    var body: some View {
        Section {
            if let line = money.campaignPlaceLine {
                IconRow(verbatim: line, symbol: "person.3", color: .secondary)
            }
            VStack(alignment: .leading, spacing: .spaceM) {
                Text(verbatim: money.campaignsHeadline)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
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
            Text(verbatim: MoneyModel.Section.campaigns.title).sectionTitle()
        } footer: {
            VStack(alignment: .leading, spacing: .space2XS) {
                Text(
                    "All candidates in the last general election, by origin of the money. Touch a column to see its total."
                )
                if let note = money.campaignScopeNote {
                    Text(verbatim: note)
                }
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
                Text(verbatim: money.revenueHeadline)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                if let line = money.revenueStateLine {
                    Text(verbatim: line)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if money.revenueTiles.contains(where: { $0.cents != nil }) {
                    StateTileMap(tiles: money.revenueTiles, focus: money.revenueFocus)
                        .id(money.revenueFocus)
                }
            }
            .padding(.vertical, .spaceXS)
        } header: {
            Text(verbatim: MoneyModel.Section.revenue.title).sectionTitle()
        } footer: {
            VStack(alignment: .leading, spacing: .space2XS) {
                Text(
                    "Federal taxes paid in each state in the last full year, for context: it's what funds every public expense, not only politics. Touch a state to see its total."
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
