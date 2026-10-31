import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

public struct ExpensesScreen: View {
    @Environment(ExpensesModel.self) private var expenses

    public init() {}

    public var body: some View {
        PublicDataContent(
            phase: expenses.phase, isEmpty: expenses.isEmpty, retry: { await expenses.load() }
        ) {
            AdaptiveList {
                ExpensesHeroSection()
                ExpensesMonthsSection()
                ExpensesYearsSection()
                ExpensesCategoriesSection()
                ExpensesSpreadSection()
                let groups = expenses.groups
                ForEach(groups) { group in
                    ExpensesMonthSection(group: group, isLast: group.id == groups.last?.id)
                }
            }
        } empty: {
            ExpensesEmptyState()
        }
        .navigationTitle(Text(verbatim: expenses.title))
        #if !os(visionOS)
            .navigationSubtitle(expenses.scopeTitle)
        #endif
        .toolbarTitleDisplayMode(.inline)
        .toolbar { ExpensesToolbar() }
        .sensoryFeedback(.selection, trigger: expenses.categoryFilter)
        .sensoryFeedback(.selection, trigger: expenses.year)
        .refreshable { await expenses.load() }
        .task { await expenses.load() }
    }
}

private struct ExpensesHeroSection: View {
    @Environment(ExpensesModel.self) private var expenses

    var body: some View {
        Section {
            MoneyCard {
                if let header = expenses.header {
                    ExpensesIdentity(slug: expenses.slug, header: header)
                }
                MoneyHeroValue(
                    chip: expenses.chip, value: expenses.total, cents: expenses.totalCents,
                    caption: expenses.receiptsCaption)
            }

        } footer: {
            Text(verbatim: expenses.sourceLine)
        }
    }
}

private struct ExpensesIdentity: View {
    let slug: String
    let header: ExpensesModel.Header

    var body: some View {
        AdaptiveRow(spacing: .spaceM) {
            PersonPortrait(slug: slug, name: header.name, party: header.party, size: .badgeXL)
            VStack(alignment: .leading, spacing: .spaceHairline) {
                Text(verbatim: header.name)
                    .font(.titleMedium)
                Text(verbatim: header.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ExpensesMonthsSection: View {
    @Environment(ExpensesModel.self) private var expenses
    @ReducesMotion private var reduceMotion

    var body: some View {
        @Bindable var expenses = expenses
        Section {
            VStack(alignment: .leading, spacing: .spaceM) {
                if let month = expenses.highlightedMonth {
                    VStack(alignment: .leading, spacing: .spaceHairline) {
                        Text(verbatim: month.name)
                            .font(.headline)
                        Text(verbatim: month.value)
                            .font(.amountTitle)
                            .monospacedDigit()
                            .contentTransition(
                                reduceMotion ? .identity : .numericText(value: month.reais)
                            )
                            .amountLine()
                    }
                    .accessibilityElement(children: .combine)
                }
                MonthlyBarsChart(
                    months: expenses.months, highlighted: expenses.highlightedMonth?.month,
                    averageReais: expenses.averageReais,
                    selection: $expenses.selectedMonth)
            }
            .padding(.vertical, .spaceXS)
        } header: {
            Text("By month").sectionTitle()
        } footer: {
            VStack(alignment: .leading, spacing: .space2XS) {
                if let peak = expenses.peakText { Text(verbatim: peak) }
                Text("Touch a month to see its total. The dashed line is the monthly average.")
                Text(verbatim: expenses.averageText)
            }
        }
    }
}

private struct ExpensesYearsSection: View {
    @Environment(ExpensesModel.self) private var expenses

    var body: some View {
        if !expenses.yearPoints.isEmpty {
            Section {
                VStack(alignment: .leading, spacing: .spaceM) {
                    if let headline = expenses.yearHeadline {
                        Text(verbatim: headline).font(.headline)
                    }
                    YearTrendChart(points: expenses.yearPoints)
                }
                .padding(.vertical, .spaceXS)
            } header: {
                Text("Year by year").sectionTitle()
            } footer: {
                Text("Allowance spent in each year of the mandate. Touch a year to see its total.")
            }
        }
    }
}

private struct ExpensesCategoriesSection: View {
    @Environment(ExpensesModel.self) private var expenses

    var body: some View {
        @Bindable var expenses = expenses
        if !expenses.categories.isEmpty {
            Section {
                RankedBarChart(
                    String(appLocalized: "By kind of expense"),
                    bars: expenses.categories.map(\.ranked),
                    selection: $expenses.categoryFilter
                )
                .accessibilityHint(Text("Shows only the receipts of this kind"))
                .padding(.vertical, .spaceXS)
            } header: {
                Text("By kind of expense").sectionTitle()
            } footer: {
                Text("Touch a kind to show only its receipts. Touch it again to show all.")
            }
        }
    }
}

private struct ExpensesSpreadSection: View {
    @Environment(ExpensesModel.self) private var expenses

    var body: some View {
        if expenses.receipts.count > 1 {
            Section {
                VStack(alignment: .leading, spacing: .spaceM) {
                    if let headline = expenses.receiptsHeadline {
                        Text(verbatim: headline).font(.headline)
                    }
                    ReceiptStripChart(
                        receipts: expenses.receipts,
                        medianReais: expenses.medianReais,
                        category: expenses.categoryFilter)
                }
                .padding(.vertical, .spaceXS)
            } header: {
                Text("Receipt sizes").sectionTitle()
            } footer: {
                Text(
                    "Each dot is one receipt, from the smallest to the largest. The dashed line is the median. Touch the chart to see a receipt."
                )
            }
        }
    }
}

private struct ExpensesEmptyState: View {
    var body: some View {
        EmptyStateView(
            title: "No receipts this year",
            description:
                "When the house publishes the receipts paid with the office allowance, they show up here with supplier and CNPJ."
        ) {
            IconRow(
                verbatim: "LATAM Linhas Aéreas", detail: "Passagens aéreas", symbol: "airplane",
                color: .retroDenim)
            IconRow(
                verbatim: "Gráfica Planalto", detail: "Divulgação", symbol: "megaphone",
                color: .retroOrange)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.plainBackground)
    }
}
