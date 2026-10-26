import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct MandateSections: View {
    @Environment(MoneyModel.self) private var money

    var body: some View {
        if money.hasMandate {
            MandateCostSection()
            MandateComparisonSection()
            if !money.quotaStateBars.isEmpty {
                QuotaStatesSection()
            }
        }
    }
}

private struct MandateCostSection: View {
    @Environment(MoneyModel.self) private var money

    var body: some View {
        Section {
            if let highlight = money.mandateHighlight {
                MandateHighlightCard(chip: money.mandateHighlightChip, total: highlight)
            }
            VStack(alignment: .leading, spacing: .spaceM) {
                Text("Monthly cost by office, item by item").font(.headline)
                MandateStackChart(
                    segments: money.mandateSegments, totals: money.mandateTotals,
                    kinds: money.mandateKinds)
            }
            .padding(.vertical, .spaceXS)
        } header: {
            Text("What a mandate costs").sectionTitle()
        } footer: {
            VStack(alignment: .leading, spacing: .space2XS) {
                Text(
                    "Gross amounts the law sets for each month; the year multiplies the month by 12. The office allowance follows the state picked in the toolbar. The housing allowance is paid only to deputies who don't live in an official apartment."
                )
                if let note = money.mandateMissingNote {
                    Text(verbatim: note)
                }
                ForEach(money.mandateActLines, id: \.self) { Text(verbatim: $0) }
                if let checked = money.mandateCheckedLine {
                    Text(verbatim: checked)
                }
                Text(verbatim: money.sourceLine(for: .mandate))
            }
        }
    }
}

private struct MandateHighlightCard: View {
    let chip: String
    let total: MandateRoleTotal

    var body: some View {
        MoneyCard(
            LinearGradient(
                colors: [.scoreboard, .scoreboard, .scoreboardAccent.opacity(.opacitySoft)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        ) {
            Chip(chip, color: .scoreboardAccent, shape: .capsule)
            AdaptiveRow(spacing: .spaceM) {
                MoneyScoreSide(label: "Per month", value: total.monthly, alignment: .leading)
                Spacer(minLength: .spaceS)
                MoneyScoreSide(label: "In 12 months", value: total.yearly, alignment: .trailing)
            }
            .contentTransition(.numericText(value: Double(total.monthlyCents)))
            .animation(.smooth, value: total.monthlyCents)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text(verbatim: total.fullYearly))
    }
}

private struct MandateComparisonSection: View {
    @Environment(MoneyModel.self) private var money

    var body: some View {
        if let comparison = money.mandateComparison {
            Section {
                IconRow(verbatim: comparison, symbol: "equal.square", color: .retroDenim)
            } footer: {
                VStack(alignment: .leading, spacing: .space2XS) {
                    ForEach(money.mandateReferenceLines, id: \.self) { Text(verbatim: $0) }
                    Text(verbatim: money.sourceLine(for: .mandate))
                }
            }
        }
    }
}

private struct QuotaStatesSection: View {
    @Environment(MoneyModel.self) private var money

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: .spaceM) {
                if let headline = money.quotaRangeHeadline {
                    Text(verbatim: headline).font(.headline)
                }
                QuotaStatesChart(bars: money.quotaStateBars)
            }
            .padding(.vertical, .spaceXS)
        } header: {
            Text("Office allowance by state").sectionTitle()
        } footer: {
            VStack(alignment: .leading, spacing: .space2XS) {
                Text(
                    "Monthly cap of a federal deputy, by the state that elected them. Touch a column to pick the state."
                )
                if let act = money.quotaActLine {
                    Text(verbatim: act)
                }
                if let checked = money.mandateCheckedLine {
                    Text(verbatim: checked)
                }
                Text(verbatim: money.sourceLine(for: .mandate))
            }
        }
    }
}
