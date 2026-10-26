import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct MandateSections: View {
    @Environment(MoneyModel.self) private var money

    var body: some View {
        if money.hasMandate {
            MandateCostSection()
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
            VStack(alignment: .leading, spacing: .spaceM) {
                Text(
                    verbatim: money.mandateComparison
                        ?? String(appLocalized: "Monthly cost by office, item by item")
                )
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
                MandateStackChart(
                    segments: money.mandateSegments, totals: money.mandateTotals,
                    kinds: money.mandateKinds)
            }
            .padding(.vertical, .spaceXS)
            ForEach(money.mandateActs) { MandateActRow(item: $0) }
        } header: {
            Text(verbatim: MoneyModel.Section.mandate.title).sectionTitle()
        } footer: {
            VStack(alignment: .leading, spacing: .space2XS) {
                Text(
                    "Gross amounts the law sets for each month. The housing allowance is paid only to those who don't live in an official apartment."
                )
                if let note = money.mandateScopeNote {
                    Text(verbatim: note)
                }
                if let note = money.mandateMissingNote {
                    Text(verbatim: note)
                }
                ForEach(money.mandateReferenceLines, id: \.self) { Text(verbatim: $0) }
                if let checked = money.mandateCheckedLine {
                    Text(verbatim: checked)
                }
                Text(verbatim: money.sourceLine(for: .mandate))
            }
        }
    }
}

private struct MandateActRow: View {
    let item: MandateActItem

    var body: some View {
        if let url = item.url {
            Link(destination: url) {
                content(showsLink: true)
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("Opens the official act"))
        } else {
            content(showsLink: false)
        }
    }

    private func content(showsLink: Bool) -> some View {
        HStack(spacing: .spaceM) {
            Image(systemName: "text.book.closed")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: .spaceHairline) {
                Text(verbatim: item.title)
                    .font(.subheadline.weight(.semibold))
                Text(verbatim: item.act)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: .spaceS)
            if showsLink {
                Image(systemName: "arrow.up.forward")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

private struct QuotaStatesSection: View {
    @Environment(MoneyModel.self) private var money

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: .spaceM) {
                if let headline = money.quotaRangeHeadline {
                    Text(verbatim: headline)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                }
                QuotaStatesChart(bars: money.quotaStateBars)
            }
            .padding(.vertical, .spaceXS)
        } header: {
            Text("Office allowance cap by state").sectionTitle()
        } footer: {
            VStack(alignment: .leading, spacing: .space2XS) {
                Text(
                    "Monthly cap of a federal deputy, by the state that elected them. States farther from Brasília get more, because flights cost more. Touch a column to see its value."
                )
                if let act = money.quotaActLine {
                    Text(verbatim: act)
                }
                Text(verbatim: money.sourceLine(for: .mandate))
            }
        }
    }
}
